# S0 photo-rating probe

Throwaway prototype for S0 (#2). It answers one question: can Apple's on-device model rate eczema photos consistently and validly on the iPhone? Delete this folder once the S0 decision is committed.

## Run

Needs Xcode 27 and an iPhone on iOS 27 with Apple Intelligence on.

```
cd prototypes/s0-photo-rating
xcodegen generate
open PhotoRatingProbe.xcodeproj
```

Select the iPhone, set a signing team, and run.

## Use

1. Choose photos from the iPhone's Photos library (up to 12). They are downscaled to 1600 px into the app's temporary folder and never written anywhere else.
2. For each photo, set the area, label it clear or flare, and give photos taken minutes apart the same non-zero group number.
3. "Rate each photo 5 times" runs the rubric on every photo and shows the seven sign scores per run, or the failure (refusal, guardrail, and so on).
4. "Context test" sends 1, 2, and 3 images in one prompt and reports prompt tokens, failures, and latency.
5. The summary is numbers only, keyed by photo number. Share it to the Mac; it is the only thing that may be committed, and only as an aggregate.

## Checks it supports (see S0)

- Spread of each sign over 5 runs (limit 1)
- Average difference between photos in a minutes-apart group (limit 1)
- Clear scores below flare, comparing the sum of signs scored in both
- Refusal rate (limit under 10%) and mean latency (about 10 seconds)
- Whether a third image fits in the context window
