# Use the user's rating as the measure until AI photo scoring is validated

**Status**: accepted

## Context

The analysis needs a daily measure of how each area's skin looks. An AI rating of a photo would save daily effort and give a per-sign breakdown, and the only model available is Apple's on-device model on an iPhone 15 Pro. Slice S0 tested it on a small set of one user's own photos (eight photos, one of them a severe flare, plus close-up crops), tuning the prompts over many rounds on those same photos. Aggregated findings:

- Rated against a reference photo of the user's clear skin, with colour-boosted photos and five runs averaged, the model matched the user's per-sign ratings with a mean absolute error of at most 0.4 on the 0–3 scale. The seven-sign total was within 0.6 of the user's (on 0–21) and ranked the photos the same way (rank correlation 0.93).
- Rated alone against the rubric, it gave nearly the same scores to mild and severe skin, so the reference photo is essential.
- Only redness, thickening, and face swelling beat guessing the same value for every photo. Dryness did no better than guessing, and bumps, scratch marks, and oozing could not be tested, because none of the photos show them. These are gaps in the data, not established limits of the model.
- The model did not detect swelling in any wording tried on the one flare photo, but eye opening against the reference photo, measured from face landmarks, did. Flake density counted in code on a skin-only close-up ordered three faces correctly; hands were not separable from noise.
- Single runs varied by 2 points on 4 of 56 photo-and-sign cells, and one rating takes about 80 seconds against a goal of about 10.
- The recipe has not been checked on photos it was not tuned on.

## Decision

For now the analysis uses the user's own look and feel ratings. The AI's rating is stored separately and shown beside the user's, and it joins the analysis as soon as it passes the criteria in the analysis rules on the app's own paired ratings. The AI rates against a reference photo per area from Release 1. Signs the model can't rate reliably are measured in code or left to the user until they validate.

## Consequences

Daily rating effort stays until promotion. Every check-in adds a paired rating, so the data needed to promote the AI rating accumulates on its own, and the decision reverses when the criteria pass. The reference photo moves from Release 3 into S4, and ratings run in the background. A different user, skin tone, camera, or iOS model update can invalidate the evidence, so every rating stores its rating version and promotion is reviewed again for each.

Rejected: making the AI the measure now (there is too little data to know how far to trust it) and dropping AI scoring (it separates a flare from clear skin and costs only background time).
