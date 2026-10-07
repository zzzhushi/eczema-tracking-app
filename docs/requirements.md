# eXzema: requirements

Functional and non-functional requirements for the app described in [the spec](spec.md). Terms follow [the glossary](../CONTEXT.md).

## How to read this

- **ID**: a stable identifier, `AREA-NN`. IDs are never reused.
- **Requirement**: one verifiable behavior, stated with "shall".
- **Pri**: Must (the release is not done without it), Should (in the release unless time runs out), Could (first to cut).
- **Rel**: the release it belongs to.
- **Stories**: user stories in the spec this requirement serves. "new" marks behavior the stories didn't cover.

| Release | Goal |
|---|---|
| R0 | Prototype: prove photo rating works on the phone |
| R1 | Collect: daily logging and automatic data, so evidence starts accumulating |
| R2 | Decide: product check and flare investigation |
| R3 | Learn: trends, suspects, natural tests, safe baseline, stepping stones |
| R4 | Nutrients: the nutrient gap checker |

## Functional requirements

### Setup and permissions (SET)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| SET-01 | On first launch, the app shall state that it finds patterns in the user's own data and does not give medical advice. | Must | R1 | new |
| SET-02 | The app shall request HealthKit read access only for the types in ENV-01, and shall work with any subset granted, treating denied types as unknown. | Must | R1 | 59 |
| SET-03 | The app shall request location access only while in use, never always. | Must | R1 | 55, 58 |
| SET-04 | The app shall request camera access only when the user first takes a photo or captures an ingredient list. | Must | R1 | 13, 43 |
| SET-05 | The app shall request notification permission only when the user enables a reminder. | Must | R1 | 1, 79 |
| SET-06 | The app shall start with two areas, face and hands. | Must | R1 | 3 |
| SET-07 | The user shall be able to add and rename areas, and retire an area without deleting its history. | Could | R1 | new |
| SET-08 | Settings shall let the user change the check-in reminder time, each category's look-back window, temperature units, and the home location. | Should | R1 | 71, new |

### Day and check-in (CHK)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| CHK-01 | The app shall keep one day record per calendar day in the phone's local time zone. | Must | R1 | new |
| CHK-02 | For each active area, the check-in shall record feel (0–10) and look (0–10). | Must | R1 | 2 |
| CHK-03 | Every check-in field shall stay editable; the latest value is the day's value, with no submit step. | Must | R1 | 4 |
| CHK-04 | The user shall be able to open and edit any past day. | Must | R1 | 5 |
| CHK-05 | A day or area without check-in values shall be stored as unknown, never as a good day. | Must | R1 | 6, 7 |
| CHK-06 | The check-in shall show a one-line summary per category of what was logged that day. | Should | R1 | 8 |
| CHK-07 | The check-in shall list the user's treatments as quick picks whose selections apply to that day only. | Must | R1 | 9 |
| CHK-08 | The user shall be able to add a treatment as topical, tied to one or more areas, or oral, applying to all areas. | Must | R1 | 9, 10 |
| CHK-09 | The check-in shall include one free-text note per day. | Must | R1 | 11 |
| CHK-10 | The app shall extract short tags from a note on-device and store them with the original text. | Should | R1 | 11 |
| CHK-11 | A note mentioning a pool, the ocean, or a hot tub shall create a water-exposure record for that day. | Should | R1 | 12 |

### Photos and photo rating (PHO)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| PHO-01 | The user shall be able to take zero or more photos per area per day. | Must | R1 | 13 |
| PHO-02 | The camera shall show a framing guide for the selected area. | Should | R1 | 14 |
| PHO-03 | The app shall store photos only inside the app, downscaled to about 1600 px, encrypted at rest, excluded from device backups, and never written to the Photos library. | Must | R1 | 21 |
| PHO-04 | The app shall score each photo on six signs from 0 to 3 using written level definitions. | Must | R0, R1 | 15 |
| PHO-05 | The app shall compute a 1–10 skin score from sign scores when displayed and shall not store it. | Must | R1 | 16 |
| PHO-06 | The app shall compare each photo with the previous photo of the same area and store a description of what changed and a better, same, or worse result. | Should | R0, R1 | 17 |
| PHO-07 | Every photo rating shall store its rating version. | Must | R1 | 19 |
| PHO-08 | The app shall store the user's look and the AI's look separately and show both when they differ by 2 or more points. | Should | R1 | 18 |
| PHO-09 | When the rating version changes, the app shall re-rate stored photos in the background and keep each prior rating until it is replaced. | Could | R1 | 20 |
| PHO-10 | The app shall show a per-area photo timeline. | Should | R1 | 22 |
| PHO-11 | The user shall be able to delete a photo, which removes the file and its ratings. | Must | R1 | new |

### Food logging (FOOD)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| FOOD-01 | Each day shall offer optional meals (breakfast, lunch, dinner, snacks), and food may be entered into any of them. | Must | R1 | 27 |
| FOOD-02 | The user shall be able to enter a meal by typing or dictating text. | Must | R1 | 24, 30 |
| FOOD-03 | The app shall split meal text into food names on-device and match each name to the catalog without the AI model. | Must | R1 | 24 |
| FOOD-04 | The app shall show the meal's text beside the matched foods, with each food's chemical levels and allergen tags. | Must | R1 | 25 |
| FOOD-05 | Words that match no food shall be kept as unrecognized entries in the meal and shown as such. | Must | R1 | 26 |
| FOOD-06 | The user shall be able to map an unrecognized entry to a catalog food or a new custom food. | Must | R1 | 26, 34 |
| FOOD-07 | A vague word shall match a generic food, which the user may change to a specific variety. | Should | R1 | 33 |
| FOOD-08 | A new custom food shall inherit the levels of a similar catalog food the user confirms, or be all unknown. | Should | R1 | 34 |
| FOOD-09 | The app shall offer suggested foods for a dish, which count only when the user accepts them. | Could | R1 | 32 |
| FOOD-10 | "Same as yesterday" shall copy a meal's foods and labels from the most recent day that has that meal. | Must | R1 | 28 |
| FOOD-11 | Each meal shall carry a source (home-made, eaten out, packaged) and a not-fresh flag. | Must | R1 | 29, 31 |
| FOOD-12 | A day with at least one food entry shall count as a logged day. | Must | R1 | 35 |
| FOOD-13 | The user shall be able to edit or delete any food entry. | Must | R1 | new |

### Reference data (CAT)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| CAT-01 | The app shall bundle a food catalog in which each food has aliases, a level for each of the six food chemicals or unknown, the nine allergen tags, and a citation per level. | Must | R1 | 36, 37, 39, 40 |
| CAT-02 | An unknown level shall display as "no data" and shall never be treated as negligible. | Must | R1 | 38 |
| CAT-03 | The first catalog shall contain the user's reviewed starting food list. | Must | R1 | 41 |
| CAT-04 | The user shall be able to override a food's level on the phone; overrides shadow bundled values and are marked as the user's. | Should | R1 | 42 |
| CAT-05 | Levels shall be resolved at analysis time, so a catalog update applies to past days. | Must | R1 | new |
| CAT-06 | The app shall bundle a common-trigger reference of cosmetic ingredients with aliases and citations. | Must | R2 | 62 |
| CAT-07 | Each catalog food shall carry good or excellent source tags for the eleven nutrients, from USDA FoodData Central. | Must | R4 | 83 |

### Products and routines (PROD)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| PROD-01 | The user shall be able to add a product by pasting its ingredient list. | Must | R1 | 43 |
| PROD-02 | The user shall be able to add a product by photographing a label or screen, with text recognized on-device and shown beside the photo for correction. | Should | R1 | 43, 44 |
| PROD-03 | Ingredient names shall be normalized and matched across their aliases. | Must | R1 | 45 |
| PROD-04 | Each product shall have a category: skincare, sunscreen, a makeup category, or background. | Must | R1 | 46, 49, 53 |
| PROD-05 | The routine shall be a set of product-and-area pairs carried forward daily until changed, with start and stop dates recorded. | Must | R1 | 46 |
| PROD-06 | Changing an area's routine shall list every product, whatever area it was added for. | Must | R1 | 47 |
| PROD-07 | The user shall be able to log a one-off use of a product without changing the routine. | Must | R1 | 48 |
| PROD-08 | Turning on "wore makeup" shall open the makeup routine by category, and each makeup category shall imply its place on the face. | Should | R1 | 49, 50 |
| PROD-09 | Quick picks shall be ordered by recency and frequency, capped in length, and searchable beyond the cap. | Should | R1 | 51 |
| PROD-10 | Leaving quick picks shall never remove a product from the product library. | Must | R1 | 52 |
| PROD-11 | A background product shall record start and stop dates and shall never be logged daily. | Should | R1 | 53 |
| PROD-12 | Deleting a product shall require confirmation that states its history will be removed. | Must | R1 | new |

### Environment and health (ENV)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| ENV-01 | On each app open, the app shall import daily summaries for every day since the last import: sleep duration and wake-ups, heart rate variability, resting heart rate, sleeping wrist temperature, menstrual cycle, time in daylight, handwashing events, and workouts including swims and routes. | Must | R1 | 59 |
| ENV-02 | The app shall fetch daily temperature, humidity, and UV index for each place the day involved, including past days. | Must | R1 | 55, 56, 57 |
| ENV-03 | The app shall fetch daily air quality alongside the weather. | Could | R1 | new |
| ENV-04 | Only coordinates rounded to 0.1° (about 11 km) shall leave the phone. | Must | R1 | 58 |
| ENV-05 | The app shall record the location at app open; a workout route shall override it for that workout's hours. | Must | R1 | 55, 56 |
| ENV-06 | A day without a location shall take the neighbouring place when the recorded days on both sides are within about 25 km and at most 7 days apart, the home location when they differ, and unknown otherwise. | Must | R1 | new |
| ENV-07 | The home location shall be the most common recorded place unless the user sets it. | Should | R1 | new |
| ENV-08 | An inferred location shall be shown on its day with a one-tap change. | Should | R1 | new |
| ENV-09 | A failed weather fetch shall be retried on later app opens, and the day's weather shall stay unknown until it succeeds. | Must | R1 | new |
| ENV-10 | The app shall compute a daily sweat load from workout heart-rate intensity and the heat and humidity at the workout's time and place. | Should | R1 | 60 |
| ENV-11 | The app shall write a daily "signs of strain" note from sleep, heart rate variability, and resting heart rate, kept out of the analysis. | Could | R1 | 61 |

### Analysis: decide (ANA, R2)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| ANA-01 | The app shall detect a flare in an area according to the flare rule (open decision 2). | Must | R2 | new |
| ANA-02 | A product check shall list each ingredient that is a user suspect, with its evidence, or a common trigger, and give an overall risk. | Must | R2 | 62 |
| ANA-03 | A product check shall offer alternatives as ingredient guidance and as library products with no linked flares, and shall never name a product outside the library. | Must | R2 | 63 |
| ANA-04 | Each ingredient's suspicion shall rise when a product containing it precedes a flare and fall when one is tolerated. | Must | R2 | 65 |
| ANA-05 | A product reaction on a high-UV day shall carry a possible-photoallergy note. | Could | R2 | 66 |
| ANA-06 | The user shall be able to compare product candidates labeled safest and most informative, with the trade-off explained. | Should | R2 | 64 |
| ANA-07 | A flare investigation shall list what differed in each category's look-back window, including notes, background-product changes, and treatments. | Must | R2 | 67 |
| ANA-08 | A flare investigation shall say when several exposures changed at once. | Must | R2 | 68 |
| ANA-09 | Look-back windows shall default to sweat and heat 0–1 days, food chemicals 0–2 days, contact products 1–4 days, and weather and handwashing 3 days of build-up. | Must | R2 | 71 |
| ANA-10 | Every result shall show a confidence and its data coverage. | Must | R2 | 70 |
| ANA-11 | Explanations shall be written only from analysis output. | Should | R2 | 76 |

### Analysis: learn (ANA, R3)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| ANA-12 | The app shall show per-area trends over the last 8 weeks and the last 6 months, with treated days marked. | Must | R3 | 69 |
| ANA-13 | The app shall rank suspects per area over core factors only. | Must | R3 | 70, 72 |
| ANA-14 | The app shall compute each day's peak, breadth, and unknown count per food chemical, following the day-level exposure rule in the spec. | Must | R3 | new |
| ANA-15 | Treated days and the 3 days after shall be excluded from suspect evidence for the treated area. | Must | R3 | 10 |
| ANA-16 | The app shall detect natural tests and grade each clean, muddied, or unknown. | Should | R3 | 73 |
| ANA-17 | The app shall infer the safe baseline after enough calm logged days, and the user shall be able to pin or remove foods. | Should | R3 | 74 |
| ANA-18 | The user shall be able to list goal foods and receive stepping-stone suggestions. | Could | R3 | 75 |
| ANA-19 | The app shall describe an area's look before and after a treatment starts, without advice. | Could | R3 | new |

### Nutrient gaps (NUT, R4)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| NUT-01 | A logged day shall count as covered for a nutrient with one excellent or two good sources. | Must | R4 | 83 |
| NUT-02 | A nutrient shall be flagged when covered on fewer than 15 of the last 30 logged days, and never before 14 logged days. | Must | R4 | 84, 85 |
| NUT-03 | A gap shall read "your logs rarely include…" with a suggestion to ask a doctor or dietitian about testing. | Must | R4 | 86 |
| NUT-04 | The vitamin D card shall show the user's daylight time. | Should | R4 | 87 |
| NUT-05 | Gaps shall appear only as an Insights card, with no badges or notifications. | Must | R4 | 88 |

### Data management (DATA)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| DATA-01 | The app shall export a structured-data backup as one JSON file that excludes photos. | Must | R1 | 80 |
| DATA-02 | The app shall export a one-row-per-day CSV of factors and ratings. | Should | R1 | 80 |
| DATA-03 | Importing a backup shall reproduce every exported record exactly. | Must | R1 | 81 |
| DATA-04 | The app shall export an optional photo archive with a CSV of date, area, and ratings, which import restores. | Could | R1 | 23, 80, 81 |
| DATA-05 | A command on the user's Mac shall reinstall the app on the connected phone and copy the latest backup off it, with an option to include photos. | Must | R1 | 78 |
| DATA-06 | The user shall be able to delete all data in the app after confirmation. | Must | R1 | new |

### Notifications (NOT)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| NOT-01 | The app shall send a check-in reminder daily at the user's chosen time, 9 pm by default. | Must | R1 | 1 |
| NOT-02 | The app shall notify the user one day before its signing expires. | Must | R1 | 79 |

### When AI or network is unavailable (FAIL)

| ID | Requirement | Pri | Rel | Stories |
|---|---|---|---|---|
| FAIL-01 | When the on-device model is unavailable, meal text shall be matched to the catalog by keyword. | Must | R1 | new |
| FAIL-02 | When the on-device model is unavailable, photos shall be stored unrated and rated once it is available. | Must | R1 | new |
| FAIL-03 | When the on-device model is unavailable, explanations shall fall back to fixed templates. | Should | R2 | new |
| FAIL-04 | Every feature other than weather shall work without a network connection. | Must | R1 | 77 |

## Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-01 | Privacy: all user data stays on the phone; the only network request is the weather and air-quality fetch with rounded coordinates; photos never reach a cloud or the Photos library. |
| NFR-02 | Cost: no paid services and no per-use AI costs. |
| NFR-03 | Ease of use: a typical day takes about a minute; an unchanged routine takes zero taps; anything that can be automatic is. |
| NFR-04 | Data honesty: unknown is never treated as zero; raw inputs are stored and combinations computed; every result shows its confidence and data coverage. |
| NFR-05 | Safety and framing: no medical advice, no diagnoses; suspects carry confidence levels. |
| NFR-06 | Resilience: weekly refresh with backup, an expiry reminder, and complete export and import. |
| NFR-07 | Compatibility: iOS 27 on an iPhone 15 Pro or newer with Apple Intelligence enabled. |
| NFR-08 | Storage: a few MB of structured data per year; photos about 150–220 MB per year. |
| NFR-09 | Maintainability: reference data is bundled, versioned, cited, and replaceable without code changes. |

## Cut line

### At risk: first to cut if time runs short

These are the Could items, in the order they would be cut: stepping stones (ANA-18), suggested foods (FOOD-09), treatment before-and-after descriptions (ANA-19), signs of strain (ENV-11), the photo archive (DATA-04), photo re-rating (PHO-09), photoallergy notes (ANA-05), air quality (ENV-03), and area management beyond face and hands (SET-07).

Re-rating carries a known cost when cut: the first iOS model update after release breaks the comparability of AI look ratings until it ships.

### Below the line: not in this version

Barcode lookup; food additives and packaged-food ingredient inference; serving sizes and raw versus cooked; face sub-areas; explicitly declared tests; named product recommendations; importing past reactions; best-fit look-back windows; mood logs, steps, and cardio fitness; supplements and iodine; nutrient food suggestions and nutrient notifications; original-resolution photos; cloud sync and iCloud backup; Siri and Shortcuts capture, widgets, and an Apple Watch check-in; a Face ID lock; a dermatologist summary; App Store or TestFlight distribution; support for anyone other than the primary user.

## Open decisions

1. **Day boundary.** CHK-01 assumes midnight in the phone's local time. Late-night entries and time-zone changes may need a different rule.
2. **Flare rule.** The glossary defines a flare only as ratings rising above an area's usual level. ANA-01 needs a measurable rule.
3. **AI unavailable.** The FAIL requirements are proposed and need confirmation.
4. **Speed targets.** No targets yet for meal parsing, photo rating, or analysis time.
5. **Accessibility.** Not yet specified, for example support for larger text sizes.
6. **Rating disagreement.** PHO-08's 2-point threshold is proposed.
