# eXzema: plan

How the work is sliced and sequenced. What the app does is in [the spec](spec.md); the testable list is in [requirements.md](requirements.md).

## Terms

- **Release**: an outcome the user can feel, made of milestones.
- **Milestone**: one thin, working path through every layer (screen, storage, analysis, result), usable on the phone.
- **Audience stage**: who gets the app: personal (the user, free signing), testers (TestFlight, paid developer account), public (App Store). Only the personal stage is in scope.

## Depth levels

- **Prototype**: throwaway; answers one question; no tests.
- **Basic**: works end to end; test-driven at the primary seam; minimal screens; no settings; known gaps listed.
- **Complete**: covers every requirement for its area.

## Development approach

- **Vertical slices.** Each milestone delivers a working end-to-end path, not a layer.
- **Manual inputs first.** Anything the user enters on the day (food, ratings, photos, location at app open) is captured early, because it can't be recovered later. Apple Health data, weather, and AI photo ratings can be filled in for past days, so they can come later. Routines can be backdated with a start date.
- **Test-driven development.** Every task starts with a failing test, then the minimum code to pass, then a refactor. Tests enter at the highest seam (the analysis as a pure computation over day records), with fakes for the on-device model, HealthKit, and weather. Each test names the requirement IDs it verifies. Behavior that only exists on the phone (camera, permissions, look and feel) gets a written manual check instead. Prototypes are not test-driven.
- **Data structure per milestone.** Each milestone defines the data it adds, following the versioning rules in the spec: raw inputs are stored and derived values recomputed, the store's schema is versioned, every schema change ships with a migration test from the previous version, and exports carry a format version.

## Prerequisites

- iOS 27 on the phone, Xcode 27 on the Mac, Apple Intelligence enabled.
- The names of the foods the user eats now (Tier 1), for M2 to match against.

## Food catalog research

Chemical levels are researched with citations and reviewed in two tiers: Tier 1 is the foods the user eats now, Tier 2 the reintroduction candidates. Research is not on the critical path for any milestone. Logged food keeps its raw text and levels are resolved when the analysis runs, so a food without researched levels counts in food-level analysis and shows no data for chemicals; once its levels are reviewed, every past day gains them.

## Release 1: food and skin

**Goal**: log what I eat each day, photograph my skin, and see which foods and food chemicals go with worse ratings. Every milestone is Basic, except M0.

| # | Thin path | First failing test | Requirements |
|---|---|---|---|
| M0 | Photo-rating prototype on the phone: the six-sign rubric, whether a reference photo fits as a third image, and whether Apple's guardrails refuse skin photos or health wording | Manual: the same photo scored 5 times; two photos taken minutes apart; a refusal is recorded, not scored | PHO-04 |
| M1 | Foundation: project, test setup, observability, versioned store that survives relaunch and reinstall | A saved day reads back identically after reloading the store | OBS-01–03, OBS-05, DATA-07, FAIL-04 |
| M2 | Type a day's food; match it to the Tier 1 food names, with chemical levels unknown until researched; keep unrecognized words; edit or delete entries | A matched food without researched levels shows no data, never negligible; an unmatched word is kept | FOOD-02–05, FOOD-12–13, CAT-01–03, CAT-05, FAIL-01 |
| M3 | Check-in for hands and face (feel and look); edit past days; record the rounded location at app open | An area without ratings is unknown, not a good day | SET-01, SET-03, SET-06, CHK-01–05, ENV-04–05 |
| M4 | A photo per area, stored in the app with a framing overlay, rated on the six signs; skin score computed | A rating stores its rating version; the skin score is not stored | SET-04, PHO-01–05, PHO-07, PHO-11, FAIL-02 |
| M5 | Food-to-skin correlation per area from each day's chemical peaks, the 0–2 day window, and both ratings, with confidence, data coverage, and links back to source days; export to Files | High-salicylate days followed by worse hand ratings rank salicylates above an unrelated chemical; a day with an unknown food is excluded | ANA-09–10, ANA-14, ANA-20, ANA-22, OBS-04, DATA-01, DATA-08 |

Expect "too early to tell" for the first weeks; meaningful results likely need 4–8 weeks of logging. Release 1 analysis focuses on the hands, where food is the suspected trigger. Face results carry a note that sun and products are not yet tracked; the analysis is re-run with that context in later releases.

## Later releases (provisional)

Goals only. Milestones are defined when a release is planned, using what Release 1 teaches.

- **Release 2, fuller logging**: meals and labels, notes and treatments, products and routines, backup and restore with the weekly refresh.
- **Release 3, explain and decide**: normal levels and the flare rule, flare investigations, the product check, photo depth (comparison, reference photos, timeline, re-rating).
- **Release 4, context and patterns**: Apple Health and weather with history filled in, trends and ranked suspects, natural tests, safe baseline, stepping stones.
- **Release 5, nutrients**: the nutrient gap checker.

## Technical limits to design around

- **On-device model context**: 4K tokens for input and output together, and images take a large share. The rubric prompt plus two or three images may not fit; M0 measures this.
- **Model guardrails**: Apple's on-device model has safety guardrails that can refuse requests. Photos of skin or health wording may trigger a refusal; M0 checks this, and refusals are logged and shown, never treated as a rating.
- **Background limits**: iOS gives apps little background time, and the on-device model may be rate-limited for apps in the background. Imports run on app open; re-rating runs while the app is open or charging.
- **Free signing**: the app expires every 7 days, a free account can run only a few sideloaded apps on one device at a time, and some capabilities (WeatherKit, push notifications) are unavailable.
- **Simulator gaps**: no camera, no real Health data, and on-device model behavior may differ from the phone. Tests use fakes; real behavior is checked on the phone.
- **Model updates**: an iOS update can change the on-device model and its outputs; rating versions make this visible.
- **Statistics, not compute**: storage and processing are tiny. The real limit is data: dozens of foods and six chemicals against a few months of days means most results stay weak until enough days are logged, and some patterns will look real by coincidence.
- **The critical path is the user's time**: mostly daily logging consistency. Catalog research and review run at the user's pace without blocking any milestone.

## Tabled

- **Patch testing support**: testing a new product on a small area (for example near the jawline, behind the ear, or the inner forearm) for 7–14 days before using it widely, with a daily check of that spot and the result feeding product suspicion. It would add a test site to areas and a short test mode to product uses. It does not affect Release 1. Clinical patch testing by an allergist is a separate option, also tabled.
- **Speed targets and accessibility**: deferred until a store release.
- **Tabs**: to be decided after the docs are reviewed.
