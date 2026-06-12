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
| Ingredient capture | VisionKit `DataScannerViewController`: on-device OCR + barcode scanning of ingredient labels. |

## Privacy

- All data lives in SwiftData on device. No server, no analytics, no accounts.
- Flare photos are stored in the app sandbox with complete file protection (encrypted at rest), never in the shared photo library.
- The LLM runs on-device via Apple Intelligence; prompts never leave the phone.

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

## Roadmap

- Bundle Open Food Facts / Open Beauty Facts slices for offline barcode → ingredient lookup
- Weather/environment correlation in the engine (currently logged but not scored)
- Photo-based severity estimation (Foundation Models image input or a small Core ML model)
- Reminders / streaks for daily logging
