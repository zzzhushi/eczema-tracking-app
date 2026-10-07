# eXzema: backlog

Later releases as outcomes, until they are tracked as GitHub issues. Decisions already made are kept as one line each so they don't need re-deciding; detailed requirements are written when a release is planned, using what Release 1 teaches. Rules and thresholds live in [the analysis rules](analysis.md).

## Release 2: fuller logging

**Outcome**: every manual input is captured with little effort.

- **Meals**: optional breakfast, lunch, dinner, and snacks, pooled per day for analysis; "same as yesterday" per meal; no saved meals.
- **Meal labels**: source (home-made, eaten out, packaged) and not fresh (leftovers, thawed, stored), a weaker factor of its own.
- **Food matching**: unrecognized words can be mapped to a catalog food or a custom food; a custom food inherits levels from a similar food or is all unknown; vague words match a generic food (fresh or aged cheese; "mushroom" means enoki by default); suggested foods for a dish count only when accepted.
- **Check-in**: a daily free-text note with extracted tags, which surfaces in flare investigations; pool, ocean, or hot tub in a note records water exposure; treatments are logged per use and never carried forward.
- **Products**: a routine of product-and-area pairs carried forward until changed; tap an area to tick from every product; one-off uses; "wore makeup" opens the makeup routine by category; quick picks ordered by recency and frequency (exact policy later); the product library is permanent.
- **Ingredient entry**: paste a list, or photograph a label or screen, shown side by side for correction.
- **Background products**: recorded once with start and stop dates, never logged daily (psyllium husk and creatine daily; collagen powder stopped October 6, 2026).
- **Backup**: full backup and restore, the weekly refresh command on the Mac with an optional photo archive, a reminder one day before signing expires, and import of every earlier export format.

## Release 3: explain and decide

**Outcome**: understand individual flares and decide on new products.

- **Flares**: per-area normal, flare state, and flare onset.
- **Flare investigation**: what differed in each look-back window, said plainly when several things changed at once.
- **Product check**: the user's suspects and common triggers in a product; alternatives as ingredient guidance and library products without linked flares, never named products from outside the library; candidates labeled safest and most informative.
- **Photo depth**: comparison with the previous photo, a reference photo that changes only with confirmation, a timeline, and background re-rating when the rating version changes; show both look ratings when they differ by 2 or more points (provisional).

## Release 4: context and patterns

**Outcome**: weather, sun, sweat, and health data join the analysis, and the app suggests what to try next.

- **Apple Health**: sleep, heart rate variability, resting heart rate, wrist temperature, menstrual cycle, time in daylight, handwashing, and workouts including swims and routes, as daily summaries, filled in for past days.
- **Weather**: temperature, humidity, UV, and air quality from Open-Meteo for each place the day involved, including past days.
- **Location**: workout routes override the app-open location; a day without a location takes the neighbouring place when the recorded days on both sides are within about 25 km and at most 7 days apart, the home location (the most common place) when they differ, and stays unknown otherwise; inferred locations show with a one-tap change.
- **Sweat load**: workout intensity adjusted for heat and humidity.
- **Patterns**: trends, ranked suspects over core factors, treatment adjustment, natural tests, an inferred safe baseline the user can adjust, goal foods with stepping stones, and the daily "signs of strain" note.

## Release 5: nutrient gaps

**Outcome**: notice nutrients a restricted diet rarely supplies.

- Eleven nutrients (vitamins D, E, B12, and C, zinc, selenium, calcium, magnesium, potassium, fibre, omega-3 ALA) tagged from USDA FoodData Central.
- Worded "your logs rarely include…" with a suggestion to ask a doctor or dietitian about testing; the vitamin D card shows daylight time; an Insights card only, with no badges or notifications.

## Public release

Tracked in case the app is ever published; none of it applies to personal use.

- A paid developer account, TestFlight, and App Store review.
- Speed targets and accessibility requirements.
- Cloud destinations for other people's exports and backups.
- Onboarding and areas for people with other triggers and body areas.
- A review of the medical framing and a privacy policy.
- Weather licensing: Open-Meteo's commercial plan or WeatherKit.
- Catalog licensing and coverage for a wider range of diets.

## Tabled

- **Patch testing support**: testing a new product on a small spot (near the jawline, behind the ear, or the inner forearm) for 7–14 days, with a daily check feeding product suspicion. Clinical patch testing by an allergist is a separate option.
- **Tabs**: four tabs (Today, Insights, Library, Data or Settings) are provisional and decided after Release 1.

## Out of scope

Voice dictation (the keyboard's built-in dictation still works); barcode lookup; food additives and packaged-food ingredient inference; serving sizes and raw versus cooked; dried spices (for now); face sub-areas; explicitly declared tests; named product recommendations; importing past reactions; best-fit look-back windows; mood logs, steps, and cardio fitness; supplements in the nutrient checker, and iodine; nutrient food suggestions and nutrient notifications; original-resolution photos; cloud sync and iCloud backup; Siri and Shortcuts capture, widgets, and an Apple Watch check-in; a Face ID lock; a dermatologist summary.
