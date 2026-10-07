# eXzema: testing

How the app is tested. Requirements for specific behavior live in the active release doc; rules being tested live in [the analysis rules](analysis.md).

## Principles

- Every behavior change starts with a written acceptance check. Automate it at the highest stable seam (the analysis as a pure computation over day records) when possible; otherwise record a manual check on the iPhone. Prototypes are exempt.
- Test names state the behavior, and each test lists the requirement IDs it verifies.
- Tests that check an exact answer use hand-built data. Real data is used only to evaluate the on-device model.

## Layers

| Layer | Checks | Data | Runs |
|---|---|---|---|
| Logic tests | Analysis rules, food matching, unknown handling, the day boundary | Hand-built day histories, including the worked examples in the analysis rules | Mac and CI, every build |
| Storage tests | Save and reload, export format, migrations | Fixture stores, one per schema version | Mac and CI, every build |
| AI evaluations | Photo-rating consistency, refusals, meal-parsing accuracy | Committed real photos and meal texts | Mac or iPhone, when the rubric, prompt, or model changes |
| Manual checks | Camera, permissions, timing, look and feel | Real use | iPhone, per milestone |

## Fakes

The on-device model, HealthKit, location, weather, and the clock and time zone sit behind interfaces. Logic and storage tests use fakes with fixed outputs, so they are deterministic and run anywhere, including CI.

## Test data

- **Hand-built histories and fixture stores** live in the repository.
- **Real photos**: a small curated set committed to the private repository, with location metadata stripped before committing, and described in a manifest (area, date, lighting, camera, and the user's own ratings).
- **Real meal texts**: typed days with the foods they should match, committed under the same exception as the photos.

## AI evaluations

- Run on the Mac with Apple Intelligence enabled, or on the iPhone; never in CI, where the model isn't available.
- Run before the M0 decisions and whenever the rating version would change.
- Measure the score spread for the same photo over 5 runs, the spread between photos taken minutes apart, the refusal rate, and meal-parsing accuracy. Thresholds are set in the M0 issue and start provisional.
- Each run is saved as a short report with its rating version.

## Manual checks

Each milestone's issue lists its manual checks as steps with an expected result. They are run on the iPhone and ticked with the build they ran on.

## Continuous integration

- GitHub Actions on a macOS runner, on every push and pull request.
- Runs the logic and storage tests; a failing run blocks merging.
- AI evaluations and manual checks are excluded.
- GitHub's runner images can lag a new Xcode release, and macOS minutes on a free private repository are limited, so the job stays lean.
