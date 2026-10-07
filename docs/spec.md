# eXzema: spec

The product, its scope, and the decisions that hold across releases. Releases are tracked as [GitHub milestones](https://github.com/zzzhushi/eczema-tracking-app/milestones) and their slices as issues; every formula and threshold lives in [the analysis rules](analysis.md), and terms in [the glossary](../CONTEXT.md).

## Problem

The user has eczema on their face and hands with several suspected triggers: food chemicals (salicylates noticeably flare their hands), chemical sunscreen filters (which flared their face), sun, sweat, and weather. They once found a sunscreen trigger by hand, comparing ingredient lists of products that flared them against ones that didn't. That worked, but it was manual and couldn't take in food, sleep, activity, or weather.

Nothing puts what they eat, what touches their skin, and their environment next to how their skin actually looked and felt each day. Food apps demand searching for every item, and health data sits unconnected in Apple Health. So they can't tell which exposure preceded a flare, or systematically expand the foods they eat safely.

## Solution

An iPhone app that collects exposures and a daily check-in of each area's skin, and analyzes them on-device to surface suspects with an honest confidence and data coverage. It never gives medical advice. Most context arrives automatically (Apple Health, weather); daily effort is a sentence of food, quick ratings, and an occasional photo. It answers, release by release: which foods go with worse skin, why a flare happened, whether to try a product, whether things are improving, and what to reintroduce next.

## Key journeys

1. **Log food**: the user types what they ate and glances at what the app matched, with unknown words kept.
2. **Check in**: each evening, the user rates feel and look for their hands and face and takes a photo; the AI rates the photo on six visible signs.
3. **See what food does to the skin**: foods and food chemicals are ranked by how the user's ratings change after eating them (Release 1).
4. **Investigate a flare**: the user sees what was different in the days before it, including sun, sweat, and new products.
5. **Check before trying**: the user pastes a product's ingredients or picks a food and sees what their history and common triggers say.
6. **Track recovery**: the user compares their skin against a normal they're aiming for, with a reference photo of their best day.
7. **Expand the diet**: the user reintroduces foods one chemical at a time toward goal foods like soy sauce and mushrooms.
8. **Keep the data**: the user exports it, and later backs it up to their Mac and restores it.

## Scope

- **Active**: Release 1, food and skin.
- **Later**: Releases 2–5 and a possible public release, tracked as [GitHub milestones and issues](https://github.com/zzzhushi/eczema-tracking-app/milestones).
- **Out of scope**: voice dictation (the keyboard's built-in dictation still works); barcode lookup; food additives and packaged-food ingredient inference; serving sizes and raw versus cooked; dried spices (for now); face sub-areas; explicitly declared tests; named product recommendations; importing past reactions; best-fit look-back windows; mood logs, steps, and cardio fitness; supplements in the nutrient checker, and iodine; nutrient food suggestions and nutrient notifications; original-resolution photos; cloud sync and iCloud backup; Siri and Shortcuts capture, widgets, and an Apple Watch check-in; a Face ID lock; a dermatologist summary.

## Safety and framing

- The app finds patterns in the user's own data. It never diagnoses, never recommends treatment, and presents suspects with a confidence rather than verdicts.
- Reintroduction and expanding the diet are favored over open-ended restriction, and formal food challenges are flagged as best done with a dietitian.
- Evidence is modest: a 2025 meta-analysis estimates salicylate, amine, and histamine intolerance among people with atopic dermatitis at roughly 53%, 32%, and 31%, with low certainty, and dietary elimination for atopic dermatitis shows only slight benefit in trials while long restrictive diets may raise the risk of IgE-mediated food allergy.

## Product decisions

### Platform

- Native iOS app on iOS 27, built with Xcode 27, for an iPhone 15 Pro or newer with Apple Intelligence enabled.
- Personal use under a free developer account: reinstalled from Xcode every 7 days; data survives reinstalls as long as the bundle identifier and Apple ID stay the same.
- No custom model training. Apple's on-device model handles language (splitting food text, explanations) and vision (photo ratings). Every conclusion comes from deterministic analysis over the user's data and bundled reference data.

### Privacy boundary

- The app never sends user data off the phone on its own. The only automatic network request is the weather and air-quality fetch, with coordinates rounded to about 11 km.
- Exports the user starts go to a destination the user picks; a cloud destination shows a warning first. For personal use, exports stay off the cloud.
- Photos stay inside the app: downscaled to about 1600 px, encrypted at rest, never in the Photos library, excluded from device and cloud backups. They reach the user's Mac only on request. Test photos stay in a local folder that git ignores; the repository is public and never holds photos.

### Data principles

- Unknown is never zero: an unknown chemical level, a day without a check-in, and a day without food entries are unknown and excluded from evidence, never counted as absent.
- Raw inputs (typed text, ratings, photos, routine changes) are stored as entered; derived values are recomputed, so changing a rule never needs a data migration.
- The store's schema, the export format, the catalog, and photo ratings each carry a version.
- A day is the local calendar date shown on the phone when an entry is logged; each entry records its time zone, and dates are never derived from UTC.

### Food catalog

- Each food has a coarse level (negligible to very high) per food chemical with a citation, or a research status when the level isn't known; plus allergen tags and aliases. Coarse levels reflect how much published measurements disagree.
- Levels are resolved when the analysis runs, so research added later applies to every past day. Research proceeds in two tiers (foods eaten now, then reintroduction candidates). It never blocks logging, but it gates the analysis that needs those levels.
- Levels come from published studies. The user's own overrides stay on the phone.

### Photos and ratings

- The AI scores six signs on 0–3 using a versioned rubric (scale source in [the analysis rules](analysis.md)); the user's look rating and the AI's are stored separately.
- Each area gets a reference photo of its best state, replaced only when the user confirms a better one (Release 3).

## Observability

Everything stays on the phone or the user's Mac; no third-party service receives logs.

- **Logging**: Apple's unified logging, with health data marked private.
- **Timing**: signposts mark the start and end of meal parsing, photo rating, and analysis, so Instruments shows how long each took.
- **Diagnostics**: crash and hang reports collected on the phone.
- **Provenance**: every analysis result links to the day records, foods, and ratings it came from, and AI explanations rest on that trail.

## Non-functional requirements

- Privacy: the app never sends user data off the phone on its own; the only automatic network request is the weather and air-quality fetch with coordinates rounded to about 11 km. Exports the user starts go to a destination the user picks, with a warning for cloud destinations. Photos never reach the Photos library, device and cloud backups, or the repository.
- Cost: no paid services and no per-use AI costs.
- Ease of use: a typical day takes about a minute; an unchanged routine takes zero taps; anything that can be automatic is.
- Data honesty: unknown is never treated as zero; raw inputs are stored and combinations computed; every result shows its confidence and data coverage.
- Safety and framing: no medical advice, no diagnoses; suspects carry confidence levels.
- Resilience: data survives relaunch and reinstall; a structured-data export exists from Release 1, and full backup and restore from Release 2.
- Compatibility: iOS 27 on an iPhone 15 Pro or newer with Apple Intelligence enabled.
- Storage: a few MB of structured data per year; photos about 150–220 MB per year.
- Maintainability: reference data is bundled, versioned, cited, and replaceable without code changes.

## Constraints and risks

Limits of the platform that shape every area of the app.

- **On-device model context**: 4K tokens for input and output together; images take a large share, so prompts stay small.
- **Model guardrails**: the model may refuse skin photos or health wording. A refusal is logged and shown, never treated as a rating.
- **Background limits**: iOS gives apps little background time, and the model may be rate-limited in the background. Work runs when the app is open or charging.
- **Free signing**: the app expires every 7 days, a free account runs only a few sideloaded apps per device, and some capabilities are unavailable.
- **Simulator gaps**: no camera, no real Health data, and model behavior may differ. Tests use fakes, and real behavior is checked on the phone.
- **Model updates**: an iOS update can change the model's outputs; rating versions make this visible.
- **Data, not compute**: the limit is how many days are logged, and some patterns will look real by coincidence.

## Further notes

- **Weather terms**: Open-Meteo is free for non-commercial use; a public release would need its commercial plan or WeatherKit.
