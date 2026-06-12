# eXzema

A privacy-first iOS app for tracking eczema and making **data-driven decisions** about triggers. Log the products, foods, and weather you're exposed to and any flare-ups; eXzema correlates your own history to surface likely triggers and checks new products against it — before they touch your skin.

> eXzema does not diagnose or treat anything. It surfaces correlations in your own logs. See a dermatologist for medical advice.

## Architecture

The "AI" is deliberately split into four parts — only one is an LLM, and nothing requires training a model:

| Layer | How it works |
|---|---|
| Trigger correlation | Deterministic engine (`Engine/CorrelationEngine.swift`): for each ingredient, how many flares it preceded (coverage) × how often using it was followed by a flare (precision). Same history in, same ranking out. |
| Eczema knowledge | Bundled reference data (`Resources/KnownAllergens.json`): EU-labeled fragrance allergens, formaldehyde-releasing preservatives, chemical UV filters, and other documented contact allergens/irritants. |
| Language layer | Apple's **Foundation Models** framework (iOS 26+): the on-device ~3B model explains the engine's numbers and assesses new products, via `@Generable` guided generation. Free, offline, unlimited. Falls back to rule-based verdicts on devices without Apple Intelligence. |
| Ingredient capture | VisionKit `DataScannerViewController`: on-device OCR + barcode scanning of ingredient labels. Barcodes resolve against a bundled slice of Open Food Facts / Open Beauty Facts (`Resources/BarcodeDB.json`, ~3,000 popular products) — fully offline. |
| Weather correlation | Logged weather is bucketed into eczema-relevant factors (cold, hot, dry air, humid, conditions) and scored by the same engine as ingredients. |

## Privacy

- All data lives in SwiftData on device. No server, no analytics, no accounts.
- Flare photos are stored in the app sandbox with complete file protection (encrypted at rest), never in the shared photo library.
- The LLM runs on-device via Apple Intelligence; prompts never leave the phone.

## Running & testing

See [TESTING.md](TESTING.md) for how to run the app in the simulator and on a physical iPhone, plus the manual test checklist. For the full design rationale, decision log, and roadmap, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Building

Requires Xcode 26+. The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`:

```sh
xcodegen generate   # only needed after changing project.yml or adding files
open eXzema.xcodeproj
```

Run tests:

```sh
xcodebuild test -project eXzema.xcodeproj -scheme eXzema -destination 'platform=iOS Simulator,name=iPhone 17'
```

Note: the AI assessment requires an Apple Intelligence–capable device (iPhone 15 Pro or newer) with Apple Intelligence enabled; everywhere else the app transparently uses its rule-based fallback.

## Regenerating bundled data

- `python3 scripts/build_barcode_db.py` — refreshes/enlarges the offline barcode database (downloads the most-scanned products from Open Food Facts + Open Beauty Facts; takes a few minutes). Bump the targets in the script for a bigger slice.
- `swift scripts/make_icon.swift` — re-renders the app icon.

## Roadmap

- Photo-based severity estimation — blocked on Foundation Models image input, which ships with the iOS 27 SDK (the Progress photo timeline in the Flares tab is the manual version meanwhile)
