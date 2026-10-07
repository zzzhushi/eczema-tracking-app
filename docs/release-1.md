# Release 1: food and skin

**Goal**: log what I eat each day, photograph my skin, and see which foods and food chemicals go with worse ratings.

Product context is in [the spec](spec.md), every formula and threshold in [the analysis rules](analysis.md), and progress and later releases in [GitHub milestones and issues](https://github.com/zzzhushi/eczema-tracking-app/milestones). Each milestone below has its own issue. Terms follow [the glossary](../CONTEXT.md).

## How to read this

- Requirement IDs (`AREA-NN`) are stable and never reused.
- **Must**: the milestone isn't done without it. **Should**: in unless explicitly cut. **Could**: first to cut.
- **Depth**: M0 is a **prototype** (throwaway, answers one question, no tests). M1–M5 are **basic** (end to end, acceptance-checked, minimal screens, no settings, known gaps listed).

## Milestones

Each milestone's thin path, acceptance checks, open questions, and exit criterion live in its issue: [M0](https://github.com/zzzhushi/eczema-tracking-app/issues/2), [M1](https://github.com/zzzhushi/eczema-tracking-app/issues/3), [M2](https://github.com/zzzhushi/eczema-tracking-app/issues/4), [M3](https://github.com/zzzhushi/eczema-tracking-app/issues/5), [M4](https://github.com/zzzhushi/eczema-tracking-app/issues/6), [M5](https://github.com/zzzhushi/eczema-tracking-app/issues/7).

Expect "too early to tell" for the first weeks; with a stable diet, most signal will come from reintroduced foods. Analysis focuses on the hands. Face results note that sun and products aren't tracked yet; later releases re-run the analysis with that context.

## Requirements

### M1: Foundation (#3)

| ID | Requirement | Pri |
|---|---|---|
| DATA-07 | The store shall carry a schema version. From M2 on, every schema change shall ship with a written migration plan and a migration test, and existing data shall never be wiped. | Must |
| FAIL-04 | Every feature other than weather shall work without a network connection. | Must |
| OBS-01 | The app shall log through Apple's unified logging with health data marked private. | Must |
| OBS-02 | The app shall provide one logging and timing-signpost convention that every feature uses. | Must |
| OBS-03 | The app shall collect crash and hang diagnostics on the phone without sending them anywhere. | Must |
| OBS-05 | Each automated test shall name the requirement IDs it verifies. | Must |
| CI-01 | Pull requests and pushes to the default branch shall run the logic and storage tests on a macOS runner, and branch protection shall block merging until the latest run passes. | Must |

### M2: Food logging (#4)

| ID | Requirement | Pri |
|---|---|---|
| FOOD-02 | The user shall be able to enter a day's food by typing text. | Must |
| FOOD-03 | The app shall split meal text into food names on-device and match each name to the catalog without the AI model. | Must |
| FOOD-04 | The app shall show the typed text beside the foods it matched, so the user can confirm the parsing. | Must |
| FOOD-05 | Words that match no food shall be kept as unrecognized entries in the meal and shown as such. | Must |
| FOOD-12 | A day with at least one food entry shall count as a logged day. | Must |
| FOOD-13 | The user shall be able to edit or delete any food entry. | Must |
| CAT-01 | The app shall bundle a food catalog in which each food has aliases, the nine allergen tags, and for each of the six food chemicals either a level with a citation or a research status (not yet researched, researched with no data, or sources conflict). | Must |
| CAT-02 | An unknown level shall display as "no data" and shall never be treated as negligible. | Must |
| CAT-03 | The first catalog shall contain the names and aliases of the foods the user eats now, with levels unknown until researched and reviewed. | Must |
| CAT-05 | Levels shall be resolved at analysis time, so a catalog update applies to past days. | Must |
| FAIL-01 | When the on-device model is unavailable, meal text shall be matched to the catalog by keyword. | Must |
| OBS-06 | Meal parsing shall be marked with a timing signpost. | Must |

### M3: Skin check-in (#5)

| ID | Requirement | Pri |
|---|---|---|
| SET-01 | On first launch, the app shall state that it finds patterns in the user's own data and does not give medical advice. | Must |
| SET-03 | The app shall request location access only while in use, never always. | Must |
| SET-06 | The app shall start with two areas, face and hands. | Must |
| CHK-01 | Each entry shall be filed under the local calendar date shown on the phone when it is logged, with its time zone recorded; dates are never derived from UTC. | Must |
| CHK-02 | For each active area, the check-in shall record feel (0–10) and look (0–10). | Must |
| CHK-12 | Each rating shall show its description (feel: itch, burning, tightness, pain; look: redness, dryness, cracks, bumps) and anchors (0 clear, 3 mild, 6 moderate, 10 worst ever). | Must |
| CHK-03 | Every check-in field shall stay editable; the latest value is the day's value, with no submit step. | Must |
| CHK-04 | The user shall be able to open and edit any past day. | Must |
| CHK-05 | A day or area without check-in values shall be stored as unknown, never as a good day. | Must |
| ENV-04 | Locations shall be rounded to 0.1° (about 11 km) before they are stored. | Must |
| ENV-05 | The app shall record the rounded location each time it is opened. | Must |

### M4: Photos and rating (#6)

| ID | Requirement | Pri |
|---|---|---|
| SET-04 | The app shall request camera access only when the user first takes a photo or captures an ingredient list. | Must |
| PHO-01 | The user shall be able to take zero or more photos per area per day, such as one of each hand. | Must |
| PHO-02 | The camera shall show a framing guide for the selected area. | Should |
| PHO-03 | The app shall store photos only inside its own storage. | Must |
| PHO-13 | Stored photos shall be downscaled to about 1600 px on the long edge. | Must |
| PHO-14 | Stored photos shall be encrypted at rest. | Must |
| PHO-15 | Stored photos shall be excluded from device and cloud backups. | Must |
| PHO-16 | The app shall never write photos to the Photos library. | Must |
| PHO-04 | The app shall score each photo on six signs from 0 to 3 using the versioned rubric; a refused or unscorable sign is stored as unscored, never as 0. | Must |
| PHO-05 | The app shall compute a 1–10 skin score from sign scores by the mapping in the analysis rules and shall not store it. | Must |
| PHO-07 | Every photo rating shall store its rating version. | Must |
| PHO-11 | The user shall be able to delete a photo, which removes the file and its ratings. | Must |
| FAIL-02 | When the on-device model is unavailable, photos shall be stored unrated and rated once it is available. | Must |
| OBS-07 | Photo rating shall be marked with a timing signpost. | Must |

### M5: Food-to-skin ranking (#7)

| ID | Requirement | Pri |
|---|---|---|
| ANA-09 | Food chemicals shall use a look-back window of 0–2 days. | Must |
| ANA-10 | Every result shall show its confidence (strong, suggestive, or too early to tell) and its data coverage (how many logged days it rests on). | Must |
| ANA-14 | The app shall compute each day's peak, breadth, and unknown count per food chemical, following the analysis rules. | Must |
| ANA-20 | For each area, the app shall rank foods and food chemicals by the food-to-skin ranking rule in the analysis rules, with confidence and data coverage. | Must |
| ANA-22 | Release 1 results for the face shall note that sun and products are not yet tracked. | Should |
| DATA-01 | The app shall export a structured-data backup as one JSON file that excludes photos, to a destination the user picks; a cloud destination shows a warning first. | Must |
| DATA-08 | Exports shall carry a format version. | Should |
| OBS-04 | Every analysis result shall link to the day records, foods, and ratings it was computed from, viewable by the user. | Must |
| OBS-08 | Analysis runs shall be marked with a timing signpost. | Must |

## Before a milestone starts

Its GitHub issue lists every path the milestone adds, each with an acceptance check, and the open questions that block it.

## Exit criteria for every milestone

- All Must requirements are satisfied; each Should is done or explicitly cut.
- Every path is checked: automated where possible, otherwise a manual check run on the iPhone and ticked in the issue with the build it ran on. Automated tests pass locally and in CI.
- The exit criterion in the milestone's issue is met and the end-to-end path is demonstrated on the phone.
- From M2 on, storage changes ship with a migration plan and a migration test.
- Relevant unavailable and offline paths are checked.
- Known limitations are recorded in the issue.
- Open questions are answered in the owning doc, or moved to a later milestone's issue with a link.
- Docs touched by the milestone are updated, and stale docs and issues are removed.

## Open questions

Open questions live in each milestone's issue. When one is decided, the owning doc is updated and the question is ticked.

## Risks

- **On-device model context**: 4K tokens for input and output together; images take a large share. M0 measures whether the rubric plus two or three images fit.
- **Model guardrails**: the model may refuse skin photos or health wording. M0 checks this; refusals are logged and shown, never treated as a rating.
- **Background limits**: iOS gives apps little background time, and the model may be rate-limited in the background. Work runs when the app is open or charging.
- **Free signing**: the app expires every 7 days; a free account runs only a few sideloaded apps per device; some capabilities are unavailable.
- **Simulator gaps**: no camera, no real Health data, and model behavior may differ. Tests use fakes; real behavior is checked on the phone.
- **CI**: runner images can lag a new Xcode release, and the model isn't available in CI, so AI evaluations run locally (see [testing](testing.md)).
- **Model updates**: an iOS update can change the model's outputs; rating versions make this visible.
- **Data, not compute**: the limit is how many days are logged, and some patterns will look real by coincidence.

## Cut line

First to cut if time runs short, in order: export format versioning (DATA-08), the face-results note (ANA-22), and the framing overlay (PHO-02). Cutting the overlay costs the most, since inconsistent photos can be re-rated but not re-taken.
