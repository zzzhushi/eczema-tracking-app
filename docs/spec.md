# eXzema: spec

The product, its scope, and the decisions that hold across releases. The active work is in [Release 1](release-1.md), every formula and threshold in [the analysis rules](analysis.md), later releases in [the backlog](backlog.md), and terms in [the glossary](../CONTEXT.md).

## Problem

The user has eczema on their face and hands with several suspected triggers: food chemicals (salicylates noticeably flare their hands), chemical sunscreen filters (which flared their face), sun, sweat, and weather. They once found a sunscreen trigger by hand, comparing ingredient lists of products that flared them against ones that didn't. That worked, but it was manual and couldn't take in food, sleep, activity, or weather.

Nothing puts what they eat, what touches their skin, and their environment next to how their skin actually looked and felt each day. Food apps demand searching for every item, and health data sits unconnected in Apple Health. So they can't tell which exposure preceded a flare, or systematically expand the foods they eat safely. They are currently on a restricted, low-chemical (RPAH-style) diet.

## Solution

An iPhone app that collects exposures and a daily check-in of each area's skin, and analyzes them on-device to surface suspects with an honest confidence and data coverage. It never gives medical advice. Most context arrives automatically (Apple Health, weather); daily effort is a sentence of food, quick ratings, and an occasional photo. It answers, release by release: which foods go with worse skin, why a flare happened, whether to try a product, whether things are improving, and what to reintroduce next.

## Key journeys

1. **Log food**: type or dictate what I ate and glance at what the app matched, with unknown words kept.
2. **Check in**: each evening, rate feel and look for my hands and face and take a photo; the AI rates the photo on six visible signs.
3. **See what food does to my skin**: rank foods and food chemicals by how my ratings change after eating them (Release 1).
4. **Investigate a flare**: see what was different in the days before it, including sun, sweat, and new products.
5. **Check before trying**: paste a product's ingredients or pick a food and see what my history and common triggers say.
6. **Track recovery**: compare my skin against a normal I'm aiming for, with a reference photo of my best day.
7. **Expand my diet**: reintroduce foods one chemical at a time toward goal foods like soy sauce and mushrooms.
8. **Keep my data**: export it, and later back it up to my Mac and restore it.

## Scope

- **Active**: Release 1, food and skin.
- **Later**: Releases 2–5 and a possible public release, as outcomes in the backlog.
- **Out of scope**: listed in the backlog.

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
- Photos stay inside the app: downscaled to about 1600 px, encrypted at rest, never in the Photos library, excluded from device and cloud backups. They reach the user's Mac only on request.

### Data principles

- Unknown is never zero: an unknown chemical level, a day without a check-in, and a day without food entries are unknown and excluded from evidence, never counted as absent.
- Raw inputs (typed text, ratings, photos, routine changes) are stored as entered; derived values are recomputed, so changing a rule never needs a data migration.
- The store's schema, the export format, the catalog, and photo ratings each carry a version.
- A day is a calendar day ending at midnight in the phone's local time zone.

### Food catalog

- Each food has a coarse level (negligible to very high) per food chemical with a citation, or a research status when the level isn't known; plus allergen tags and aliases. Coarse levels reflect how much published measurements disagree.
- Levels are resolved when the analysis runs, so research added later applies to every past day. Research proceeds in two tiers (foods eaten now, then reintroduction candidates) and never blocks a milestone.
- Levels come from published studies, not the RPAH handbook ([ADR 0002](adr/0002-chemical-levels-from-published-studies.md)). The user's own overrides stay on the phone.

### Photos and ratings

- The AI scores six signs on 0–3 using a versioned rubric; the user's look rating and the AI's are stored separately.
- Each area gets a reference photo of its best state, replaced only when the user confirms a better one.

## Observability

Everything stays on the phone or the user's Mac; no third-party service receives logs.

- **Logging**: Apple's unified logging, with health data marked private.
- **Timing**: signposts around meal parsing, photo rating, and analysis.
- **Diagnostics**: crash and hang reports collected on the phone.
- **Provenance**: every analysis result links to the day records, foods, and ratings it came from, and AI explanations rest on that trail.
- **Requirement traceability**: each automated test names the requirement IDs it verifies.

## Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-01 | Privacy: the app never sends user data off the phone on its own; the only automatic network request is the weather and air-quality fetch with coordinates rounded to about 11 km. Exports the user starts go to a destination the user picks, with a warning for cloud destinations. Photos never reach the Photos library or device and cloud backups. |
| NFR-02 | Cost: no paid services and no per-use AI costs. |
| NFR-03 | Ease of use: a typical day takes about a minute; an unchanged routine takes zero taps; anything that can be automatic is. |
| NFR-04 | Data honesty: unknown is never treated as zero; raw inputs are stored and combinations computed; every result shows its confidence and data coverage. |
| NFR-05 | Safety and framing: no medical advice, no diagnoses; suspects carry confidence levels. |
| NFR-06 | Resilience: data survives relaunch and reinstall; a structured-data export exists from Release 1, and full backup and restore from Release 2. |
| NFR-07 | Compatibility: iOS 27 on an iPhone 15 Pro or newer with Apple Intelligence enabled. |
| NFR-08 | Storage: a few MB of structured data per year; photos about 150–220 MB per year. |
| NFR-09 | Maintainability: reference data is bundled, versioned, cited, and replaceable without code changes. |
## Further notes

- **Weather terms**: Open-Meteo is free for non-commercial use; a public release would need its commercial plan or WeatherKit.
- **Storage**: structured data is a few MB per year; photos about 150–220 MB per year.
