# eXzema: testing

How the app is tested. Requirements for specific behavior live in the active release doc; rules being tested live in [the analysis rules](analysis.md).

## Principles

- Every behavior change starts with a written acceptance check. Automate it at the highest stable seam (the analysis as a pure computation over day records) when possible; otherwise record a manual check on the iPhone. Prototypes are exempt from automated regression tests, but not from acceptance checks.
- Test names state the behavior, and tests are grouped into suites by capability (for example, food logging).
- Tests that check an exact answer use hand-built data. Real data is used only to evaluate the on-device model.

## Layers

| Layer | Checks | Data | Runs |
|---|---|---|---|
| Logic tests | Analysis rules, food matching, unknown handling, the day boundary | Hand-built day histories, including the worked examples in the analysis rules | Mac and CI, every build |
| Storage tests | Save and reload, export format, migrations | Fixture stores, one per schema version | Mac and CI, every build |
| AI evaluations | Photo-rating consistency and validity, refusals, meal-parsing accuracy | Local real photos; synthetic meal texts | Mac or iPhone, when the rubric, prompt, or model changes |
| Manual checks | Camera, permissions, timing, look and feel | Real use | iPhone, per task |

## Fakes

The on-device model, HealthKit, location, weather, and the clock and time zone sit behind interfaces. Logic and storage tests use fakes with fixed outputs, so they are deterministic and run anywhere, including CI.

## Test data

- **Hand-built histories and fixture stores** live in the repository.
- **Real photos**: a small curated set kept in a local folder that git ignores, together with their manifest (file name, area, date, lighting, camera, the user's own ratings, and which pairs should score as clear versus flare) and raw evaluation reports. Only AI evaluations use photos, and they never run in CI, so committing them would gain nothing and would make them public permanently. The repository holds only an example manifest showing the format.
- Raw health-derived labels (dates, ratings, per-photo scores) never go into the repository, PRs, issues, CI logs, or artifacts.
- **Meal texts**: synthetic days written in the user's style, with the foods they should match, never copied from real logs.

## AI evaluations

- A separate test set that never runs by default or in CI, where the model isn't available. Run on the Mac with Apple Intelligence enabled, or on the iPhone.
- A photo listed in the manifest but missing on the machine is reported as skipped, not failed.
- Run before the T0 decisions and whenever the rating version would change.
- Measure the score spread for the same photo over 5 runs, the spread between photos taken minutes apart, the refusal rate, and meal-parsing accuracy.
- Check validity as well as consistency, since a model can be consistently wrong: photos the user has labeled must score in the expected order (a clear photo below a flare photo) and within expected per-sign ranges.
- Thresholds are set in the T0 issue and start provisional. Mac runs are for iteration; the T0 viability gate runs on the target iPhone.
- Each run is saved locally as a report with its rating version. Only the T0 decision is committed, as an aggregated summary using opaque photo IDs.

## Manual checks

Each task's issue lists its manual checks as steps with an expected result. They are run on the iPhone and ticked with the build they ran on.

## Continuous integration

- GitHub Actions on a macOS runner, on pull requests and on pushes to the default branch.
- Runs the logic and storage tests; branch protection on the default branch blocks merging until the latest run passes.
- AI evaluations and manual checks are excluded.
- GitHub's runner images can lag a new Xcode release.

## Definition of done

A task is done when all of these hold. Task issues link here instead of copying it.

- Every path in the issue is checked: automated where possible, otherwise a manual check run on the iPhone and ticked in the issue with the build it ran on.
- The tests pass locally and in CI.
- The issue's end-to-end path is demonstrated on the phone.
- Relevant offline and unavailable-model paths are checked.
- A change to the stored schema ships with a written migration plan and a migration test, and never wipes existing data.
- the behavior docs the task touches are updated in the same pull request as the code, and anything it makes stale is deleted.
- Known limitations are recorded in the issue.
- Open questions are answered in the owning doc, or moved to a later issue with a link.
