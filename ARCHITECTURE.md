# eXzema — Architecture, Decisions & Roadmap

This document records what has been built, **why** it was built that way, how to run and validate it, and what comes next. Companion docs: [README.md](README.md) (overview) and [TESTING.md](TESTING.md) (detailed run/test instructions).

## 1. The product in one paragraph

eXzema lets someone with eczema log daily exposures (skincare/makeup/food products with full ingredient lists, weather) and flare-ups (severity, photos, [POEM score](https://www.nottingham.ac.uk/research/groups/cebd/resources/poem.aspx)). It correlates that history to surface likely triggers, and checks *new* products against both the personal history and a catalog of documented allergens — before they touch skin. It explicitly does **not** diagnose or treat; it supports data-driven decisions. Hard requirements: everything local (no server, no accounts, no photo uploads) and zero recurring AI cost.

## 2. Current state

All of the original requirements are implemented except photo-based AI severity (blocked on Apple tooling — see §6):

| Feature | Where |
|---|---|
| Daily logging: products/foods used, weather, flares (photos + POEM), with backfill for past days | `Views/TodayView.swift`, `Views/FlaresView.swift` |
| Product library with parsed, normalized ingredient lists | `Views/ProductsView.swift`, `Engine/IngredientParser.swift` |
| Trigger insights (ingredients + weather factors) | `Views/InsightsView.swift`, `Engine/CorrelationEngine.swift` |
| "Check a product" against history + allergen catalog, with AI or rule-based verdict | `Views/CheckProductView.swift`, `AI/AssistantService.swift` |
| Live scanner: ingredient-label OCR and offline barcode lookup | `Views/ScannerSheet.swift`, `Engine/BarcodeLookup.swift` |
| Photo progress timeline | `PhotoTimelineView` in `Views/FlaresView.swift` |
| Daily logging reminder (local notification) | `Engine/ReminderManager.swift` |
| Bundled data: 41 documented allergens, ~3,000-product barcode DB | `Resources/KnownAllergens.json`, `Resources/BarcodeDB.json` |

## 3. Architecture decisions and rationale

### D1. No custom model training — "AI" is four separable parts

The instinct for an "AI eczema app" is to train an eczema model. We deliberately didn't:

- Public eczema image datasets are small (hundreds to a few thousand images) and research-licensed; even dermatologists [disagree substantially on eczema segmentation](https://pubmed.ncbi.nlm.nih.gov/36090300/), which caps what supervised training can achieve.
- Trigger identification doesn't need learning at all — it's correlation over the user's own structured logs.
- A trained model is a black box; for a health-adjacent app, explainability ("preceded 3 of 4 flares") beats a confidence score.

So the system is: **deterministic engine** (math) + **reference data** (eczema knowledge) + **on-device LLM** (language only) + **OS vision APIs** (capture). Each part is replaceable without touching the others.

### D2. Trigger detection is deterministic math, not an LLM

`CorrelationEngine` scores every factor (ingredient or weather bucket) as **precision × coverage**:

- *coverage* — of all flares, what share had this factor present in the 3 days before (sensitivity);
- *precision* — of all days the factor was present, what share were followed by a flare within 3 days.

Rationale: same history in, same ranking out (testable, no hallucinated ingredient facts); trivially explainable in the UI; runs instantly on ancient hardware. The LLM is *never* the source of a number — it only narrates the engine's output, which structurally prevents it from inventing history.

Known limitation (documented in the UI): daily staples like water rank high on coverage because they're always present. Precision dampens but doesn't eliminate this; a future iteration could add a baseline-correction (e.g. relative risk vs. non-exposure days).

The 3-day window is a deliberate simplification — contact dermatitis reactions typically appear within hours to ~2–3 days of exposure. It's a single constant (`windowDays`) so it can become a user setting later.

### D3. Eczema specificity comes from bundled data, not model weights

What makes the app "know about eczema" is curated reference data:

- `KnownAllergens.json` — the [26 EU-labeled fragrance allergens](https://ec.europa.eu/growth/tools-databases/cosing/), formaldehyde-releasing preservatives, isothiazolinones, chemical UV filters, lanolin, and other allergens drawn from published contact-dermatitis sources (e.g. the [ACDS](https://www.contactderm.org/) core series). Each entry has aliases (oxybenzone → benzophenone-3) and a plain-language note.
- `BarcodeDB.json` — a popularity-ranked slice of [Open Food Facts](https://world.openfoodfacts.org/data) and [Open Beauty Facts](https://world.openbeautyfacts.org/) (~3,000 products, 1.1 MB), so barcode → ingredients works **fully offline**.

Rationale: data files are auditable, updatable without retraining anything, and keep the runtime offline. The privacy detail matters: a live barcode API call would reveal *what the user scans*; a bundled slice reveals nothing.

Build-time note for the barcode script (`scripts/build_barcode_db.py`): the OFF **v2 search API silently ignores `sort_by` and country filters**. The script therefore gets popularity-ranked codes from the newer [search-a-licious service](https://search.openfoodfacts.org/docs) (`sort_by=-unique_scans_n`), then resolves names/ingredients in batches of 100 via the v2 API's `code=` parameter, with retry/backoff for the API's frequent 503s.

### D4. Language layer: Apple Foundation Models, with a mandatory fallback

The conversational/explanatory layer uses the [Foundation Models framework](https://developer.apple.com/documentation/FoundationModels) (iOS 26+), which exposes Apple's ~3B on-device model ([background](https://machinelearning.apple.com/research/introducing-apple-foundation-models)): free, offline, unlimited — which is what makes the "zero AI cost" requirement hold.

Two implementation choices worth recording:

- **Guided generation** (`@Generable` + `@Guide`) forces the model to emit a typed `AIProductAssessment` at the token level — no JSON parsing, no malformed output path.
- **Every AI call has a deterministic twin.** `AssistantService.assess` computes the rule-based verdict *first* and returns it whenever the model is unavailable (non-Apple-Intelligence device, model still downloading, Apple Intelligence off) or throws. The app is fully functional with AI off; AI is a presentation upgrade, not a dependency. The UI labels which mode produced a verdict, and the Insights tab surfaces the live availability status with remediation hints.

The session instructions pin the model to the data in the prompt, forbid diagnosis/treatment advice, and allow only patch-test/avoidance/see-a-dermatologist suggestions — the regulatory guardrail (see D8) enforced at the prompt level.

### D5. Storage: SwiftData + sandboxed photos with file protection

- Structured data lives in [SwiftData](https://developer.apple.com/documentation/swiftdata) on device. No CloudKit sync yet (a deliberate omission: sync is the first feature that would move health data off the device; if added, it must be end-to-end-encrypted private-database CloudKit, opt-in).
- Flare photos are written to the app sandbox (`Documents/FlarePhotos`) with [`.completeFileProtection`](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/1616757-completefileprotection) (encrypted at rest while locked), and **never** to the shared photo library — so no other app, and no photo-library sync, ever sees them. Models store only filenames.
- Reminders use [UserNotifications](https://developer.apple.com/documentation/usernotifications) local scheduling — no push service.

### D6. Capture: VisionKit, not a custom pipeline

[`DataScannerViewController`](https://developer.apple.com/documentation/visionkit/datascannerviewcontroller) provides live on-device OCR and barcode recognition with tap-to-select, in ~100 lines of integration. Tapped label text feeds `IngredientParser` (separator handling, INCI normalization, alias mapping, parenthetical stripping, dedupe); tapped barcodes go through `BarcodeLookup` (with leading-zero normalization, since UPC-A scans often arrive as 13-digit EAN). Unknown barcodes show a status message rather than polluting the ingredient field with digits.

### D7. Severity input: user-rated + POEM now; photo AI later

v1 uses a 0–10 slider plus the optional validated [POEM questionnaire](https://www.nottingham.ac.uk/research/groups/cebd/resources/poem.aspx). Photo-based scoring is feasible (research models correlate with dermatologist EASI, e.g. [Scientific Reports 2021](https://www.nature.com/articles/s41598-021-85489-8); [smartphone photos are adequate input](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9907712/)) but is **deferred**: Foundation Models gained image input at WWDC26, which requires the **iOS 27 SDK** — not buildable with Xcode 26.5. The photo Progress timeline is the manual stand-in, and photos are already being collected in a usable form.

### D8. Regulatory framing: general wellness, not medical device

Everything user-facing says "correlation in your own logs," never diagnosis or treatment. This keeps the app inside the FDA's [general wellness, low-risk device policy](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policies-low-risk-devices) and is enforced in three places: UI copy (Insights disclaimer), the rule-based verdict text, and the LLM system instructions.

### D9. Project generation: XcodeGen

The project is declared in `project.yml` and generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen). Rationale: a ~40-line reviewable YAML instead of merge-hostile pbxproj edits. Both the YAML and the generated `.xcodeproj` are committed so the project opens without tooling. Consequence to remember: `xcodegen generate` rewrites the pbxproj, so **signing-team selections made in Xcode are lost on regeneration** — pin `DEVELOPMENT_TEAM` in `project.yml` (see TESTING.md).

## 4. Data model

```
Product            name, category, ingredientsRaw, ingredients [normalized], isArchived
ExposureEntry      date, → Product            (one row = "used product P on day D")
FlareEvent         date, severity 0–10, poemScore?, bodyAreas, notes, photoFilenames
EnvironmentEntry   date, location, temperatureC?, humidityPercent?, conditions, notes
```

`HistoryAssembler` converts these into plain value types (`ExposureRecord`, `FlareRecord`, `EnvironmentRecord`) so `CorrelationEngine` stays pure and unit-testable without a database. Weather entries are bucketed into categorical factors (≤5 °C cold, ≥27 °C hot, ≤35% dry, ≥70% humid, named conditions; "clear" is never scored) and pushed through the same engine.

## 5. How to run and validate

Full instructions live in [TESTING.md](TESTING.md). The short version:

- **Simulator**: `open eXzema.xcodeproj`, pick an iPhone simulator, ⌘R. Camera scanning and (usually) the LLM are unavailable there; everything else works.
- **Your iPhone**: free Apple ID in Xcode → select Personal Team under Signing & Capabilities → enable Developer Mode on the phone → ⌘R. AI features need an iPhone 15 Pro+ with Apple Intelligence on.
- **Automated tests** (9 tests: engine math, weather bucketing, parser/alias normalization, allergen matching, barcode DB integrity):
  ```sh
  xcodebuild test -project eXzema.xcodeproj -scheme eXzema \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
  ```
- **Manual validation**: TESTING.md has a 10-minute happy-path script (seeded with a methylisothiazolinone cream and an oxybenzone sunscreen) plus checklists for persistence, engine edge cases, privacy verification (photos absent from Photos app; full function in Airplane Mode), and phone-only checks (scanner, AI on/off fallback).
- **Regenerating bundled data**: `python3 scripts/build_barcode_db.py` (barcode DB), `swift scripts/make_icon.swift` (icon), `xcodegen generate` (project).

## 6. Next steps

Ordered by expected value:

1. **Live with it.** Real daily use will reprioritize everything below.
2. **Photo-based severity (when Xcode 27 / iOS 27 SDK ships).** Feed flare photos to Foundation Models' image input for a coarse better/same/worse comparison against the previous photo, with the user's own rating as the source of truth. The honest target is *trend assistance*, not clinical scoring (see D1 research caveats).
3. **Baseline-corrected trigger scoring.** Replace precision × coverage with something like relative risk (flare rate on exposed vs. unexposed days) to stop daily staples from ranking; needs care with sparse data.
4. **Engine-aware product detail.** Per-flare "what changed vs. your routine" diff: ingredients newly introduced in the window vs. long-running ones.
5. **Bigger/regional barcode slice** — bump targets in `build_barcode_db.py`; consider a country filter once OFF's search service supports it reliably.
6. **Data export** (JSON/CSV share sheet) — useful for dermatologist visits and as a manual backup story while there's no sync.
7. **Optional E2E-encrypted iCloud sync** (CloudKit private DB) — only if multi-device matters; revisit the privacy posture explicitly.
8. **Notification deep-links** (reminder → opens Today tab logging sheet directly).

## 7. Reference index

**Apple frameworks**: [Foundation Models](https://developer.apple.com/documentation/FoundationModels) · [Apple's on-device foundation model](https://machinelearning.apple.com/research/introducing-apple-foundation-models) · [WWDC26: Foundation Models updates](https://developer.apple.com/videos/play/wwdc2026/339/) · [SwiftData](https://developer.apple.com/documentation/swiftdata) · [VisionKit DataScanner](https://developer.apple.com/documentation/visionkit/datascannerviewcontroller) · [UserNotifications](https://developer.apple.com/documentation/usernotifications) · [File protection](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/1616757-completefileprotection)

**Data sources**: [Open Food Facts](https://world.openfoodfacts.org/data) · [Open Beauty Facts](https://world.openbeautyfacts.org/) · [OFF search-a-licious API](https://search.openfoodfacts.org/docs) · [EU CosIng cosmetic ingredient DB](https://ec.europa.eu/growth/tools-databases/cosing/) · [American Contact Dermatitis Society](https://www.contactderm.org/)

**Clinical/research**: [POEM score](https://www.nottingham.ac.uk/research/groups/cebd/resources/poem.aspx) · [Eczema segmentation rater-dependence](https://pubmed.ncbi.nlm.nih.gov/36090300/) · [DNN severity scoring of atopic dermatitis](https://www.nature.com/articles/s41598-021-85489-8) · [Smartphone-photo EASI/SCORAD validation](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9907712/) · [FDA general wellness guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policies-low-risk-devices)

**Tooling**: [XcodeGen](https://github.com/yonaskolb/XcodeGen)
