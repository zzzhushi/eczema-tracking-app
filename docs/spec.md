# eXzema: spec

## Problem Statement

The user has eczema on their face and hands with several suspected triggers: food chemicals (salicylates noticeably flare their hands), chemical sunscreen filters (which flared their face), sun, sweat, and weather. They previously identified a sunscreen trigger by hand: comparing ingredient lists of products that flared them against ones that didn't, with a general-purpose chatbot's help. That worked, but it was manual, lived in a chat history, and couldn't take in food, sleep, activity, or weather.

Today there is no single place where what they eat, what they put on their skin, how they slept, how hard they ran, and the weather sit next to how their skin actually looked and felt each day. Food logging apps demand typing and searching for every item. Health data sits in Apple Health, unconnected to skin. As a result, the user can't tell whether a flare came from Tuesday's tomato pasta, Wednesday's hot run, or a new product, and can't systematically expand the set of foods they safely eat.

The user wants all data and AI to stay on their phone, with no cloud storage and no AI costs, and wants daily use to take about a minute.

## Solution

An iPhone app that collects the user's exposures (foods, product uses, weather, health data) and a daily check-in of each area's skin, and analyzes them on-device to surface suspects with an honest confidence and data coverage. It never gives medical advice.

Most data arrives automatically: sleep, heart rate variability, wrist temperature, menstrual cycle, daylight, handwashing, and workouts from Apple Health; weather, UV, and air quality from a public weather service using a rounded location. The user's daily effort is a typed or dictated sentence of food per meal (with "same as yesterday"), four quick ratings in the evening, and the occasional photo or routine change.

The analysis answers four questions, built in this order:

1. **Should I try this?** A product check of a new product's ingredients, or a new food's chemistry, against the user's suspects and common triggers, with alternatives drawn from ingredient guidance and the user's own history.
2. **Why did this flare happen?** A flare investigation listing what was different in each category's look-back window, including notes.
3. **Is it getting better?** Trends per area over weeks and months.
4. **What's linked to my flares?** Ranked suspects per area over core factors, with confidence and data coverage.

Alongside these, the app grades natural tests (new or reintroduced exposures) as clean or muddied, infers the user's safe baseline, and suggests stepping stones toward goal foods such as soy sauce and mushrooms.

## User Stories

### Daily check-in

1. As the user, I want one evening check-in reminder, so that rating my skin becomes a habit at a consistent time of day.
2. As the user, I want to rate feel and look separately for each area, so that itch that starts before anything is visible is captured as an early warning.
3. As the user, I want to track face and hands to start, so that the check-in matches where I actually flare.
4. As the user, I want to add or edit anything throughout the day and have the latest state count, so that there is no separate submit step.
5. As the user, I want to backfill a day I missed, so that one forgotten evening doesn't lose that day.
6. As the user, I want good days recorded like any other day, so that the analysis can tell triggers from coincidence.
7. As the user, I want days without a check-in treated as unknown rather than good, so that skipped days never create false evidence.
8. As the user, I want a short "what was used" line under each category in the check-in, so that I can confirm the day at a glance.
9. As the user, I want to record treatments only on days I use them, so that a medicated cream isn't silently carried forward.
10. As the user, I want treated days marked in the analysis, so that improvement from a cream isn't credited to something else.
11. As the user, I want a free-text note for one-off activities like painting or cleaning, so that unusual exposures are captured without forms.
12. As the user, I want to note pool, ocean, or hot-tub time in free text, so that water exposure is recorded even without a workout.

### Photos

13. As the user, I want to optionally photograph an area during the check-in, so that I have a visual record when something changes.
14. As the user, I want a framing guide when taking a photo, so that distance and angle stay consistent between days.
15. As the user, I want the AI to score six signs (redness, dryness or flaking, bumps or blisters, cracks or broken skin, thickening, oozing or crusting) on 0–3 with written definitions, so that ratings stay steady from day to day.
16. As the user, I want a 1–10 skin score derived from the signs, so that I get an easy indicator of how my skin is doing.
17. As the user, I want the AI to compare a photo with the previous photo of the same area and describe what changed, so that I get nuance like "slightly drier, new crack on the right index finger".
18. As the user, I want my look rating and the AI's look rating kept separately, so that disagreements are visible and weighting can change later.
19. As the user, I want each photo rating to record its rating version, so that ratings from different models or rubrics are never silently mixed.
20. As the user, I want stored photos re-rated in the background when the rating version changes, so that my history stays comparable across iOS model updates.
21. As the user, I want photos stored only inside the app, downscaled, never in my Photos library, and excluded from backups, so that they don't take space or appear in my camera roll.
22. As the user, I want to view my photos as a timeline per area, so that I can see progress over time.
23. As the user, I want to export selected photos when I choose, so that I can share them with a dermatologist if needed.

### Food logging

24. As the user, I want to type or dictate what I ate as a sentence, so that logging is easier than searching a food database.
25. As the user, I want what I wrote shown side by side with the foods the app found, with their chemical levels, so that I can check the result at a glance.
26. As the user, I want words the app can't match shown as unrecognized rather than dropped, so that a day doesn't look emptier than it was.
27. As the user, I want to group food into optional meals, so that a single eaten-out dinner doesn't label my whole day.
28. As the user, I want "same as yesterday" per meal, so that repeated meals take one tap.
29. As the user, I want to mark a meal's source as home-made, eaten out, or packaged, so that eating out can be analyzed as its own factor.
30. As the user, I want to paste a restaurant's menu description, so that eaten-out meals are as exact as I can make them.
31. As the user, I want to mark a meal as not fresh (leftovers, thawed, stored), so that histamine-related effects can be considered as a weaker factor.
32. As the user, I want only the foods I write to count, with suggested foods for a dish offered as opt-in additions, so that the app never invents what I ate.
33. As the user, I want vague words like "cheese" to match a generic food (fresh or aged cheese), with a specific variety optional, so that I'm not forced through dropdowns.
34. As the user, I want a new food to inherit levels from the closest catalog food, or be marked unknown, so that unfamiliar foods don't block logging.
35. As the user, I want any food entry to mark the day as logged, so that I'm not asked to confirm completeness.

### Food catalog

36. As the user, I want each catalog food to carry chemical levels for salicylates, oxalates, amines, histamine, glutamates, and nickel, so that evidence pools across foods that share a chemical.
37. As the user, I want chemical levels on a coarse scale from negligible to very high, so that the data doesn't pretend to precision that published measurements don't have.
38. As the user, I want unknown levels shown as "no data" and never treated as negligible, so that missing data can't masquerade as a low-chemical day.
39. As the user, I want each food tagged with the nine common allergens it contains, so that milk-, wheat-, or nut-containing foods can be analyzed together.
40. As the user, I want every chemical level to cite its published source, so that I can review and trust the catalog.
41. As the user, I want to provide my starting food list and review the researched levels before they ship, so that the catalog reflects foods I actually eat.
42. As the user, I want to override a food's level on my phone, so that I can apply what I trust from the RPAH handbook or my own experience.

### Products

43. As the user, I want to add a product by pasting its ingredient list or photographing the label or a webpage, so that setup happens once per product.
44. As the user, I want the photographed ingredient list shown side by side with what was recognized, so that I can fix reading errors.
45. As the user, I want ingredient aliases matched (for example avobenzone and butyl methoxydibenzoylmethane), so that overlaps between products aren't missed.
46. As the user, I want my skincare kept as a routine of product-and-area pairs carried forward daily, so that an unchanged day needs zero taps.
47. As the user, I want to tap an area to tick or untick products, with every product available for every area, so that I can record using Vaseline on my face only today.
48. As the user, I want to log a one-off use without adding it to my routine, so that a hotel shampoo or a patch test is captured.
49. As the user, I want "wore makeup" to open my makeup routine by category, so that I can tick or add the products I used.
50. As the user, I want a makeup product's category to imply where on the face it goes, so that I don't specify sub-areas.
51. As the user, I want quick picks ordered by recency and frequency, so that my current foundation shows before one I stopped using.
52. As the user, I want leaving quick picks to never remove a product from my library, so that past reactions keep their evidence.
53. As the user, I want to record background products like shampoo once with a start date, so that their ingredients are checked without daily logging.
54. As the user, I want switching a background product to appear in flare investigations, so that changes are noticed even though constant use isn't analyzed.

### Environment and health

55. As the user, I want weather, UV, humidity, and air quality fetched automatically for the place I opened the app, so that environmental factors need no effort.
56. As the user, I want weather for outdoor workouts fetched for the workout's route and hours, so that a hike away from home is captured correctly.
57. As the user, I want weather fetched for past days too, so that missed days fill in automatically.
58. As the user, I want only a rounded location sent to the weather service, so that my precise whereabouts never leave the phone.
59. As the user, I want sleep, heart rate variability, resting heart rate, wrist temperature, menstrual cycle, daylight time, handwashing, and swims read from Apple Health as daily summaries, so that the analysis uses data I already produce.
60. As the user, I want a daily sweat load computed from workout intensity and the heat and humidity during it, so that a hot 12 km run is distinguished from an easy cool jog.
61. As the user, I want a daily "signs of strain" note, so that I can see when my body seemed under strain, as a curiosity separate from the trigger analysis.

### Analysis

62. As the user, I want to paste a new product's ingredients and see which are my suspects and which are common triggers, so that I can decide before it touches my skin.
63. As the user, I want alternatives as ingredient guidance plus products from my own history that didn't flare me, so that suggestions are grounded in real data.
64. As the user, I want product candidates labeled safest and most informative with the trade-off explained, so that I can choose between protecting my skin and narrowing my suspects.
65. As the user, I want each ingredient's suspicion to rise with reactions and fall with tolerance, so that one tolerated product doesn't fully clear an ingredient.
66. As the user, I want possible photoallergy noted using UV and daylight data, so that sunscreen reactions on sunny days are interpreted correctly.
67. As the user, I want a flare investigation listing what was different in each category's look-back window, including notes and background-product changes, so that I can reason about a specific flare.
68. As the user, I want the investigation to say when several things changed at once, so that a muddied flare isn't presented as a clear cause.
69. As the user, I want per-area trends over weeks and months, so that I can see whether my skin is improving.
70. As the user, I want ranked suspects per area with a confidence and the number of logged days behind them, so that thin evidence looks thin.
71. As the user, I want look-back windows set per category from known reaction timing and editable, so that same-day sweat and slower contact allergy are each judged fairly.
72. As the user, I want only core factors tested, so that coincidences among dozens of factors don't drown out real suspects.
73. As the user, I want new or reintroduced exposures treated as natural tests and graded clean or muddied, so that I get experiment-quality evidence without planning experiments.
74. As the user, I want my safe baseline inferred from my first calm weeks with no setup, so that the app learns my control diet from ordinary logging.
75. As the user, I want to list goal foods and get stepping-stone suggestions that isolate one food chemical at a time, so that I can expand my diet methodically.
76. As the user, I want explanations written in plain language from the analysis's own numbers, so that I understand results without the AI inventing facts.

### Data and operations

77. As the user, I want everything stored only on my phone, so that my health data never goes to a cloud.
78. As the user, I want a weekly refresh command on my Mac that reinstalls the app and copies the latest backup off the phone, so that the free signing never lapses unnoticed and my data lives on two of my devices.
79. As the user, I want a notification a day before the app's signing expires, so that the weekly refresh doesn't catch me by surprise.
80. As the user, I want to export a full backup and a one-row-per-day spreadsheet, so that I can restore the app and analyze my data externally.
81. As the user, I want to import a backup, so that a new phone or a deleted app can be fully restored.

## Implementation Decisions

### Platform and constraints

- Native iOS app targeting iOS 27, built with Xcode 27, run on an iPhone 15 Pro or newer with Apple Intelligence enabled. iOS 27 is required for on-device image input to Apple's Foundation Models framework.
- Distributed only through a free Apple developer account during this phase: the app is reinstalled from Xcode every 7 days. Data survives reinstalls as long as the bundle identifier and Apple ID stay the same and the app is never deleted.
- Capabilities available on the free account: HealthKit. Apple's WeatherKit is not available on the free account, so weather comes from a third-party service.
- No custom model training. AI is Apple's on-device model, used only for language (splitting food text, writing explanations) and vision (photo ratings and comparisons). All conclusions come from deterministic analysis over the user's data and bundled reference data.
- No network calls except the weather and air-quality fetch, which sends only rounded coordinates.

### Modules

- **Day store.** On-device database holding check-ins, meals and food entries, product uses, routine changes, treatments, notes, and daily health and weather summaries. Every record belongs to a calendar day and an area where relevant. Structured data is small (a few MB per year).
- **Food catalog.** Bundled, versioned reference data: foods with aliases, generic and specific variants, a chemical level per food chemical (unknown allowed), allergen tags, and a citation per level. User overrides are stored separately and shadow bundled levels. Levels are resolved at analysis time, so catalog corrections improve past analysis.
- **Common-trigger reference.** Bundled, versioned reference of cosmetic ingredients widely reported to cause reactions (fragrance allergens, preservatives such as isothiazolinones, chemical UV filters, and so on), with aliases and citations. Compiled from published sources and reviewed by the user, like the food catalog.
- **Food parser.** Turns a meal's text into foods. The on-device model splits text into food names and proposes suggested foods; matching names to the catalog is deterministic. Unmatched words become unrecognized entries. The model never assigns chemical levels.
- **Ingredient reader.** Turns pasted text or on-device text recognition of a photo into a normalized ingredient list with alias matching.
- **Photo rater.** Rates a photo against the six-sign rubric and compares it with the previous photo of the same area, behind an interface that hides the model. Records the rating version with every result. Re-rates stored photos when the version changes. The skin score is computed from sign scores, never stored as the source of truth.
- **Health importer.** Reads daily summaries from HealthKit on each app open, filling any days since the last import, including workout routes for outdoor workouts and swims.
- **Weather importer.** Fetches daily weather, UV, humidity, and air quality from Open-Meteo for each location the day involved: the place the app was opened and the routes of outdoor workouts. A backfilled day uses the most recent known location, which the user can change.
- **Analysis engine.** A pure computation over day records and reference data, producing product checks, flare investigations, trends, ranked suspects, natural-test grades, the safe baseline, and stepping-stone suggestions. Default look-back windows: sweat and heat 0–1 days, food chemicals 0–2 days, contact products 1–4 days, weather and handwashing build-up over 3 days; all editable. Tests only core factors. Every result carries a confidence (strong, suggestive, too early to tell) and its data coverage.
- **Product suspicion.** Per-ingredient suspicion levels that rise when a product containing the ingredient precedes a flare and fall when one is tolerated, adjusted by area and concentration cues. Product candidates are scored as safest (no current suspects) or most informative (splits the current suspects most evenly).
- **Narrator.** The on-device model turns analysis-engine output into plain-language explanations and the daily "signs of strain" note. It receives only the engine's results and never states facts absent from them.
- **Export and import.** A full backup as JSON (restorable) plus a one-row-per-day CSV for external analysis. Photos are exported separately and only on request.
- **Weekly refresh command.** A script on the user's Mac that builds and reinstalls the app on the connected phone and copies the latest backup out of the app's data container.
- **Notifications.** The evening check-in reminder and the signing-expiry reminder one day ahead.

### Key data rules

- Unknown is never zero: an unknown chemical level, a day without a check-in, and a day without a food entry are unknown and are excluded from evidence rather than counted as absent.
- Raw inputs are stored and combinations are computed: the user's look and the AI's look are stored separately; written foods and accepted suggested foods are distinguishable; the not-fresh label is its own weaker factor rather than a modifier of food levels.
- Routines are product-and-area pairs with start and stop dates. Treatments are never carried forward.
- Natural tests are inferred from first-time or reintroduced exposures relative to the safe baseline and graded clean or muddied by what else changed in the window, including eaten-out meals.

### Core factors

Food chemicals (six), allergen tags (nine), eating out, not fresh, products and their ingredients, makeup, background-product changes, treatments, UV, temperature, humidity, air quality, daylight time, sleep, heart rate variability, resting heart rate, wrist temperature, menstrual cycle, sweat load, handwashing, water exposure.

### Screens

Four tabs: Today (meals, routine summary, automatic data, the check-in and photo ratings), Insights (flare investigations, trends, suspects, natural tests, next experiment), Library (foods, products, background products, product checks and candidate comparisons), and Data (backup, export, import, signing expiry). Mockups were reviewed during the design session.

### Build order

0. Prerequisites: iOS 27 on the phone, Xcode 27 on the Mac, Apple Intelligence enabled, the watch's Handwashing Timer enabled.
1. A throwaway photo-rating prototype on the phone, answering whether the six-sign rubric and photo comparison work within the on-device model's 4K-token context on an iPhone 15 Pro.
2. Logging: check-in, food parsing, products and routines, Health and weather import, export and import, the weekly refresh command, and notifications, so that data collection starts. The food catalog and common-trigger reference are researched in parallel from the user's starting list.
3. Product check and flare investigation.
4. Trends, ranked suspects, natural tests, safe baseline, and stepping stones.

## Testing Decisions

- A good test exercises external behavior through the highest available seam: given day records and reference data, assert the findings. Tests never assert on internal data structures or the wording of AI output.
- **Primary seam: the analysis engine as a pure function** from day records and reference data to findings. Most behavior is tested here with hand-built day histories, for example "unknown chemical levels never produce a low-load day", "a flare after two changes is reported as muddied", "a tolerated product lowers but does not clear an ingredient's suspicion".
- **Model seam: the photo rater and food parser sit behind interfaces**, so tests substitute a fake model and check the surrounding logic (deterministic catalog matching, unrecognized entries, rating-version handling, re-rating).
- **Reference-data validation:** every chemical level decodes, every level has a citation, slugs and aliases are unique, and aliases resolve, so a typo can't ship as a silent unknown.
- **Export round-trip:** export then import reproduces identical day records.
- **Importer tests:** HealthKit and weather importers are tested against recorded fixture responses, including backfill of missed days and route-based locations.
- **Photo-rating prototype (manual):** rate the same photo repeatedly and two photos taken minutes apart, to measure consistency before the check-in depends on it.
- **Prior art:** none; this is a fresh repository.

## Out of Scope

- Barcode lookup for products and packaged foods.
- Food additives and packaged-food ingredient inference.
- Serving sizes, raw versus cooked, and face sub-areas.
- Explicitly declared tests; tests are inferred only.
- Named product recommendations from the AI.
- Importing past history or known reactions.
- Best-fit look-back windows (a later exploratory feature).
- Mood logs, steps, and cardio fitness as factors.
- Cloud sync, iCloud backup, and photo backup.
- Siri and Shortcuts capture, widgets, Apple Watch check-in, Face ID lock, and a dermatologist summary (later).
- App Store or TestFlight distribution, and support for users other than the primary user.

## Further Notes

- **Evidence and framing.** A 2025 meta-analysis estimates salicylate, amine, and histamine intolerance among people with atopic dermatitis at roughly 53%, 32%, and 31%, with low certainty. Dietary elimination for atopic dermatitis shows only slight benefit in trials, and long restrictive diets may raise the risk of developing IgE-mediated food allergy. The app therefore favors reintroduction and expanding the diet, says when formal challenges are best done with a dietitian, and presents suspects with confidence levels rather than verdicts.
- **RPAH licensing.** The RPAH Elimination Diet Handbook is a copyrighted commercial book. Bundled chemical levels come from the published studies the field relies on (for salicylates, Swain et al. 1985 and later measurements), with RPAH used only to decide which foods to include first. The user's own overrides stay on their phone.
- **Weather terms.** Open-Meteo is free for non-commercial use. A future paid release would need its commercial plan or WeatherKit with a paid developer account.
- **Storage estimates.** Downscaled photos at two areas per day are about 150–220 MB per year; structured data is a few MB per year.
