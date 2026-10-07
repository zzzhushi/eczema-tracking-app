# eXzema: requirements

Functional and non-functional requirements for the app described in [the spec](spec.md). Terms follow [the glossary](../CONTEXT.md).

## How to read this

- **ID**: a stable identifier, `AREA-NN`. IDs are never reused.
- **Requirement**: one verifiable behavior, stated with "shall".
- **Pri**: Must (the milestone is not done without it), Should (in unless time runs out), Could (first to cut).
- **When**: `R1·M2` means Release 1, milestone 2 (see [the plan](plan.md)). `Later` means a later release; those requirements are provisional and will be revised when that release is planned.
- **Stories**: user stories in the spec this requirement serves. "new" marks behavior the stories didn't cover.

Release 1 requirements are built to the Basic depth defined in the plan.

## Functional requirements

### Setup and permissions (SET)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| SET-01 | On first launch, the app shall state that it finds patterns in the user's own data and does not give medical advice. | Must | R1·M3 | new |
| SET-02 | The app shall request HealthKit read access only for the types in ENV-01, and shall work with any subset granted, treating denied types as unknown. | Must | Later | 59 |
| SET-03 | The app shall request location access only while in use, never always. | Must | R1·M3 | 55, 58 |
| SET-04 | The app shall request camera access only when the user first takes a photo or captures an ingredient list. | Must | R1·M4 | 13, 43 |
| SET-05 | The app shall request notification permission only when the user enables a reminder. | Must | Later | 1, 79 |
| SET-06 | The app shall start with two areas, face and hands. | Must | R1·M3 | 3 |
| SET-07 | The user shall be able to add and rename areas, and retire an area without deleting its history. | Could | Later | new |
| SET-08 | Settings shall let the user change the check-in reminder time, each category's look-back window, temperature units, and the home location. | Should | Later | 71, new |

### Day and check-in (CHK)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| CHK-01 | The app shall keep one day record per calendar day in the phone's local time zone. | Must | R1·M3 | new |
| CHK-02 | For each active area, the check-in shall record feel (0–10) and look (0–10). | Must | R1·M3 | 2 |
| CHK-03 | Every check-in field shall stay editable; the latest value is the day's value, with no submit step. | Must | R1·M3 | 4 |
| CHK-04 | The user shall be able to open and edit any past day. | Must | R1·M3 | 5 |
| CHK-05 | A day or area without check-in values shall be stored as unknown, never as a good day. | Must | R1·M3 | 6, 7 |
| CHK-06 | The check-in shall show a one-line summary per category of what was logged that day. | Should | Later | 8 |
| CHK-07 | The check-in shall list the user's treatments as quick picks whose selections apply to that day only. | Must | Later | 9 |
| CHK-08 | The user shall be able to add a treatment as topical, tied to one or more areas, or oral, applying to all areas. | Must | Later | 9, 10 |
| CHK-09 | The check-in shall include one free-text note per day. | Must | Later | 11 |
| CHK-10 | The app shall extract short tags from a note on-device and store them with the original text. | Should | Later | 11 |
| CHK-11 | A note mentioning a pool, the ocean, or a hot tub shall create a water-exposure record for that day. | Should | Later | 12 |

### Photos and photo rating (PHO)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| PHO-01 | The user shall be able to take zero or more photos per area per day. | Must | R1·M4 | 13 |
| PHO-02 | The camera shall show a framing guide for the selected area. | Should | R1·M4 | 14 |
| PHO-03 | The app shall store photos only inside the app, downscaled to about 1600 px, encrypted at rest, excluded from device backups, and never written to the Photos library. | Must | R1·M4 | 21 |
| PHO-04 | The app shall score each photo on six signs from 0 to 3 using written level definitions. | Must | R1·M4 | 15 |
| PHO-05 | The app shall compute a 1–10 skin score from sign scores when displayed and shall not store it. | Must | R1·M4 | 16 |
| PHO-06 | The app shall compare each photo with the previous photo of the same area and store a description of what changed and a better, same, or worse result. | Should | Later | 17 |
| PHO-07 | Every photo rating shall store its rating version. | Must | R1·M4 | 19 |
| PHO-08 | The app shall store the user's look and the AI's look separately and show both when they differ by 2 or more points. | Should | Later | 18 |
| PHO-09 | When the rating version changes, the app shall re-rate stored photos in the background and keep each prior rating until it is replaced. | Could | Later | 20 |
| PHO-10 | The app shall show a per-area photo timeline. | Should | Later | 22 |
| PHO-11 | The user shall be able to delete a photo, which removes the file and its ratings. | Must | R1·M4 | new |
| PHO-12 | The app shall keep a reference photo per area, propose a better-rated photo as the new reference with a before-and-after view, and switch only when the user confirms. | Should | Later | new |

### Food logging (FOOD)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| FOOD-01 | Each day shall offer optional meals (breakfast, lunch, dinner, snacks), and food may be entered into any of them. | Must | Later | 27 |
| FOOD-02 | The user shall be able to enter a meal by typing or dictating text. | Must | R1·M2 | 24, 30 |
| FOOD-03 | The app shall split meal text into food names on-device and match each name to the catalog without the AI model. | Must | R1·M2 | 24 |
| FOOD-04 | The app shall show the meal's text beside the matched foods, with each food's chemical levels and allergen tags. | Must | R1·M2 | 25 |
| FOOD-05 | Words that match no food shall be kept as unrecognized entries in the meal and shown as such. | Must | R1·M2 | 26 |
| FOOD-06 | The user shall be able to map an unrecognized entry to a catalog food or a new custom food. | Must | Later | 26, 34 |
| FOOD-07 | A vague word shall match a generic food, which the user may change to a specific variety. | Should | Later | 33 |
| FOOD-08 | A new custom food shall inherit the levels of a similar catalog food the user confirms, or be all unknown. | Should | Later | 34 |
| FOOD-09 | The app shall offer suggested foods for a dish, which count only when the user accepts them. | Could | Later | 32 |
| FOOD-10 | "Same as yesterday" shall copy a meal's foods and labels from the most recent day that has that meal. | Must | Later | 28 |
| FOOD-11 | Each meal shall carry a source (home-made, eaten out, packaged) and a not-fresh flag. | Must | Later | 29, 31 |
| FOOD-12 | A day with at least one food entry shall count as a logged day. | Must | R1·M2 | 35 |
| FOOD-13 | The user shall be able to edit or delete any food entry. | Must | R1·M2 | new |

### Reference data (CAT)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| CAT-01 | The app shall bundle a food catalog in which each food has aliases, a level for each of the six food chemicals or unknown, the nine allergen tags, and a citation per level. | Must | R1·M2 | 36, 37, 39, 40 |
| CAT-02 | An unknown level shall display as "no data" and shall never be treated as negligible. | Must | R1·M2 | 38 |
| CAT-03 | The first catalog shall contain the user's reviewed starting food list. | Must | R1·M2 | 41 |
| CAT-04 | The user shall be able to override a food's level on the phone; overrides shadow bundled values and are marked as the user's. | Should | Later | 42 |
| CAT-05 | Levels shall be resolved at analysis time, so a catalog update applies to past days. | Must | R1·M2 | new |
| CAT-06 | The app shall bundle a common-trigger reference of cosmetic ingredients with aliases and citations. | Must | Later | 62 |
| CAT-07 | Each catalog food shall carry good or excellent source tags for the eleven nutrients, from USDA FoodData Central. | Must | Later | 83 |

### Products and routines (PROD)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| PROD-01 | The user shall be able to add a product by pasting its ingredient list. | Must | Later | 43 |
| PROD-02 | The user shall be able to add a product by photographing a label or screen, with text recognized on-device and shown beside the photo for correction. | Should | Later | 43, 44 |
| PROD-03 | Ingredient names shall be normalized and matched across their aliases. | Must | Later | 45 |
| PROD-04 | Each product shall have a category: skincare, sunscreen, a makeup category, or background. | Must | Later | 46, 49, 53 |
| PROD-05 | The routine shall be a set of product-and-area pairs carried forward daily until changed, with start and stop dates recorded. | Must | Later | 46 |
| PROD-06 | Changing an area's routine shall list every product, whatever area it was added for. | Must | Later | 47 |
| PROD-07 | The user shall be able to log a one-off use of a product without changing the routine. | Must | Later | 48 |
| PROD-08 | Turning on "wore makeup" shall open the makeup routine by category, and each makeup category shall imply its place on the face. | Should | Later | 49, 50 |
| PROD-09 | Quick picks shall be ordered by recency and frequency, capped in length, and searchable beyond the cap. | Should | Later | 51 |
| PROD-10 | Leaving quick picks shall never remove a product from the product library. | Must | Later | 52 |
| PROD-11 | A background product shall record start and stop dates and shall never be logged daily. | Should | Later | 53 |
| PROD-12 | Deleting a product shall require confirmation that states its history will be removed. | Must | Later | new |

### Environment and health (ENV)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| ENV-01 | On each app open, the app shall import daily summaries for every day since the last import: sleep duration and wake-ups, heart rate variability, resting heart rate, sleeping wrist temperature, menstrual cycle, time in daylight, handwashing events, and workouts including swims and routes. | Must | Later | 59 |
| ENV-02 | The app shall fetch daily temperature, humidity, and UV index for each place the day involved, including past days. | Must | Later | 55, 56, 57 |
| ENV-03 | The app shall fetch daily air quality alongside the weather. | Could | Later | new |
| ENV-04 | Only coordinates rounded to 0.1° (about 11 km) shall leave the phone. | Must | R1·M3 | 58 |
| ENV-05 | The app shall record the location at app open; a workout route shall override it for that workout's hours. | Must | R1·M3 | 55, 56 |
| ENV-06 | A day without a location shall take the neighbouring place when the recorded days on both sides are within about 25 km and at most 7 days apart, the home location when they differ, and unknown otherwise. | Must | Later | new |
| ENV-07 | The home location shall be the most common recorded place unless the user sets it. | Should | Later | new |
| ENV-08 | An inferred location shall be shown on its day with a one-tap change. | Should | Later | new |
| ENV-09 | A failed weather fetch shall be retried on later app opens, and the day's weather shall stay unknown until it succeeds. | Must | Later | new |
| ENV-10 | The app shall compute a daily sweat load from workout heart-rate intensity and the heat and humidity at the workout's time and place. | Should | Later | 60 |
| ENV-11 | The app shall write a daily "signs of strain" note from sleep, heart rate variability, and resting heart rate, kept out of the analysis. | Could | Later | 61 |

### Analysis: decide (ANA)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| ANA-01 | The app shall treat an area as in a flare while look or feel is 2 or more points above its normal, and shall mark a flare onset when either rises 2 or more points above the previous 7 days. | Must | Later | new |
| ANA-02 | A product check shall list each ingredient that is a user suspect, with its evidence, or a common trigger, and give an overall risk. | Must | Later | 62 |
| ANA-03 | A product check shall offer alternatives as ingredient guidance and as library products with no linked flares, and shall never name a product outside the library. | Must | Later | 63 |
| ANA-04 | Each ingredient's suspicion shall rise when a product containing it precedes a flare and fall when one is tolerated. | Must | Later | 65 |
| ANA-05 | A product reaction on a high-UV day shall carry a possible-photoallergy note. | Could | Later | 66 |
| ANA-06 | The user shall be able to compare product candidates labeled safest and most informative, with the trade-off explained. | Should | Later | 64 |
| ANA-07 | A flare investigation shall list what differed in each category's look-back window, including notes, background-product changes, and treatments. | Must | Later | 67 |
| ANA-08 | A flare investigation shall say when several exposures changed at once. | Must | Later | 68 |
| ANA-09 | Look-back windows shall default to sweat and heat 0–1 days, food chemicals 0–2 days, contact products 1–4 days, and weather and handwashing 3 days of build-up; Release 1 uses only the food window. | Must | R1·M5 | 71 |
| ANA-10 | Every result shall show a confidence and its data coverage. | Must | R1·M5 | 70 |
| ANA-11 | Explanations shall be written only from analysis output. | Should | Later | 76 |

### Analysis: learn (ANA)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| ANA-12 | The app shall show per-area trends over the last 8 weeks and the last 6 months, with treated days marked. | Must | Later | 69 |
| ANA-13 | The app shall rank suspects per area over core factors only. | Must | Later | 70, 72 |
| ANA-14 | The app shall compute each day's peak, breadth, and unknown count per food chemical, following the day-level exposure rule in the spec. | Must | R1·M5 | new |
| ANA-15 | Treated days and the 3 days after shall be excluded from suspect evidence for the treated area. | Must | Later | 10 |
| ANA-16 | The app shall detect natural tests and grade each clean, muddied, or unknown. | Should | Later | 73 |
| ANA-17 | The app shall infer the safe baseline after enough calm logged days, and the user shall be able to pin or remove foods. | Should | Later | 74 |
| ANA-18 | The user shall be able to list goal foods and receive stepping-stone suggestions. | Could | Later | 75 |
| ANA-19 | The app shall describe an area's look before and after a treatment starts, without advice. | Could | Later | new |
| ANA-20 | For each area, the app shall rank foods and food chemicals by how much worse the area's ratings were in the 0–2 days after they were eaten, with confidence and data coverage. | Must | R1·M5 | 70 |
| ANA-21 | Each area shall have a normal level set by the user, and the app shall propose lowering it after a week sustained below it. | Should | Later | new |
| ANA-22 | Release 1 results for the face shall note that sun and products are not yet tracked. | Should | R1·M5 | new |

### Nutrient gaps (NUT)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| NUT-01 | A logged day shall count as covered for a nutrient with one excellent or two good sources. | Must | Later | 83 |
| NUT-02 | A nutrient shall be flagged when covered on fewer than 15 of the last 30 logged days, and never before 14 logged days. | Must | Later | 84, 85 |
| NUT-03 | A gap shall read "your logs rarely include…" with a suggestion to ask a doctor or dietitian about testing. | Must | Later | 86 |
| NUT-04 | The vitamin D card shall show the user's daylight time. | Should | Later | 87 |
| NUT-05 | Gaps shall appear only as an Insights card, with no badges or notifications. | Must | Later | 88 |

### Data management (DATA)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| DATA-01 | The app shall export a structured-data backup as one JSON file that excludes photos; in Release 1, saved to Files on request. | Must | R1·M5 | 80 |
| DATA-02 | The app shall export a one-row-per-day CSV of factors and ratings. | Should | Later | 80 |
| DATA-03 | Importing a backup shall reproduce every exported record exactly. | Must | Later | 81 |
| DATA-04 | The app shall export an optional photo archive with a CSV of date, area, and ratings, which import restores. | Could | Later | 23, 80, 81 |
| DATA-05 | A command on the user's Mac shall reinstall the app on the connected phone and copy the latest backup off it, with an option to include photos. | Must | Later | 78 |
| DATA-06 | The user shall be able to delete all data in the app after confirmation. | Must | Later | new |
| DATA-07 | The store shall carry a schema version, and every schema change shall migrate existing data or wipe it with a visible notice, never silently. | Must | R1·M1 | new |
| DATA-08 | Exports shall carry a format version, and import shall accept every earlier format. | Should | R1·M5 | new |

### Notifications (NOT)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| NOT-01 | The app shall send a check-in reminder daily at the user's chosen time, 9 pm by default. | Must | Later | 1 |
| NOT-02 | The app shall notify the user one day before its signing expires. | Must | Later | 79 |

### When AI or network is unavailable (FAIL)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| FAIL-01 | When the on-device model is unavailable, meal text shall be matched to the catalog by keyword. | Must | R1·M2 | new |
| FAIL-02 | When the on-device model is unavailable, photos shall be stored unrated and rated once it is available. | Must | R1·M4 | new |
| FAIL-03 | When the on-device model is unavailable, explanations shall fall back to fixed templates. | Should | Later | new |
| FAIL-04 | Every feature other than weather shall work without a network connection. | Must | R1·M1 | 77 |

### Observability (OBS)

| ID | Requirement | Pri | When | Stories |
|---|---|---|---|---|
| OBS-01 | The app shall log through Apple's unified logging with health data marked private. | Must | R1·M1 | new |
| OBS-02 | The app shall mark meal parsing, photo rating, and analysis with timing signposts. | Must | R1·M1 | new |
| OBS-03 | The app shall collect crash and hang diagnostics on the phone without sending them anywhere. | Should | R1·M1 | new |
| OBS-04 | Every analysis result shall link to the day records, foods, and ratings it was computed from, viewable by the user. | Must | R1·M5 | 70, 76 |
| OBS-05 | Each automated test shall name the requirement IDs it verifies. | Must | R1·M1 | new |

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

### Release 1: first to cut if time runs short

In order: crash and hang diagnostics (OBS-03), export format versioning (DATA-08), the face-results note (ANA-22), and the framing overlay (PHO-02). Cutting the overlay costs the most, since inconsistent photos can be re-rated but not re-taken.

### Later releases

Provisional. Their Could items are the first candidates to cut when each release is planned: stepping stones (ANA-18), suggested foods (FOOD-09), treatment before-and-after descriptions (ANA-19), signs of strain (ENV-11), the photo archive (DATA-04), photo re-rating (PHO-09), photoallergy notes (ANA-05), air quality (ENV-03), and area management beyond face and hands (SET-07).

### Below the line: not in this version

Barcode lookup; food additives and packaged-food ingredient inference; serving sizes and raw versus cooked; face sub-areas; explicitly declared tests; named product recommendations; importing past reactions; best-fit look-back windows; mood logs, steps, and cardio fitness; supplements and iodine; nutrient food suggestions and nutrient notifications; original-resolution photos; cloud sync and iCloud backup; Siri and Shortcuts capture, widgets, and an Apple Watch check-in; a Face ID lock; a dermatologist summary; patch testing support (tabled); speed targets and accessibility requirements (until a store release); App Store or TestFlight distribution; support for anyone other than the primary user.

## Open decisions

1. **AI unavailable.** The FAIL requirements are proposed and need confirmation.
2. **Rating disagreement.** PHO-08's 2-point threshold is proposed.
