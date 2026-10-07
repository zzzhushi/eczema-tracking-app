# eXzema: testing

How the app is tested. Current behavior lives in `docs/behavior`, proposed behavior and acceptance live in slice issues, and formulas and thresholds live in [the analysis rules](analysis.md).

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
| Manual checks | Camera, permissions, timing, look and feel | Real use | iPhone, per slice |

## Fakes

The on-device model, HealthKit, location, weather, and the clock and time zone sit behind interfaces. Logic and storage tests use fakes with fixed outputs, so they are deterministic and run anywhere, including CI.

## Test data

- **Hand-built histories and fixture stores** live in the repository.
- **Real photos**: a small curated set kept in a local folder that git ignores, together with their manifest (file name, area, date, lighting, camera, the user's own ratings, and which pairs should score as clear versus flare) and raw evaluation reports. Only AI evaluations use photos, and they never run in CI, so committing them would gain nothing and would make them public permanently. The repository holds only an example manifest showing the format. A pre-commit hook blocks staging the folder or any photo file; enable it once per clone with `git config core.hooksPath .githooks`.
- No image of the user, in any form (a photo, crop, thumbnail, screenshot, or rendering), ever goes into the repository, PRs, issues, CI logs, or artifacts. Ratings and scores per photo may be recorded there, labeled only by opaque IDs.
- **Meal texts**: synthetic days written in the user's style, with the foods they should match, never copied from real logs.

## AI evaluations

- A separate test set that never runs by default or in CI, where the model isn't available. Run on the Mac with Apple Intelligence enabled, or on the iPhone.
- A photo listed in the manifest but missing on the machine is reported as skipped, not failed.
- Run before the S0 decisions and whenever the rating version would change.
- Measure the score spread for the same photo over 5 runs, the spread between photos taken minutes apart, the refusal rate, and meal-parsing accuracy.
- Check validity as well as consistency, since a model can be consistently wrong: photos the user has labeled must score in the expected order (a clear photo below a flare photo) and within expected per-sign ranges.
- Fix pass criteria before running, and state them per photo and per sign, not only as averages. Compare every result with a constant guess (the same number for every photo): a sign whose labeled photos all have one value can't be validated, and a result that doesn't beat the guess shows no skill.
- Keep tuning photos apart from validation photos. Prompts, thresholds, and methods may change while tuning; a rating recipe counts as validated only when it passes unchanged on photos taken on other days that it was never tuned on.
- Thresholds are set in the S0 issue and start provisional. Mac runs are for iteration; the S0 viability gate runs on the target iPhone.
- Each run is saved locally as a report with its rating version. The S0 decision is committed as a summary using opaque photo IDs; raw reports stay local.

## Manual checks

Each slice's issue lists its manual checks as steps with an expected result. They are run on the iPhone and ticked with the build they ran on.

Log redaction is lifted while a debugger is attached, so a redaction check runs on a build launched from the home screen. To read logs afterwards, pull them with the phone connected and filter to the app:

```bash
/usr/bin/log collect --device --last 1d --output ~/exzema-logs.logarchive
/usr/bin/log show ~/exzema-logs.logarchive --predicate 'subsystem == "com.zzzhushi.exzema"'
```

The archive covers the whole phone; keep it out of the repository and delete it after use.

## Continuous integration

- GitHub Actions on pull requests and on pushes to the default branch, in one `test` job on the `xcode-27` runner label (`macos-latest` still has an older Xcode).
- Runs the core package's tests, the pre-commit hook's test, and an unsigned build of the app for the iOS simulator; branch protection on the default branch blocks merging until the latest run passes.
- AI evaluations and manual checks are excluded.
- GitHub's runner images can lag a new Xcode release. If the `xcode-27` label breaks, fall back to `macos-latest` running only the core package's tests, which must then avoid Xcode 27-only APIs.

## Definition of done

A slice is done when all of these hold. Slice issues link here instead of copying it.

- Every Must item in the issue is done, and every Should item is done or explicitly cut in the issue.
- The issue's exit criterion is met, and its end-to-end path is demonstrated on the phone.
- Every path in the issue is checked: automated where possible, otherwise a manual check run on the iPhone and ticked in the issue with the build it ran on.
- The tests pass locally and in CI.
- Relevant offline and unavailable-model paths are checked.
- A change to the stored schema ships with a written migration plan and a migration test, and never wipes existing data.
- The behavior docs the slice touches are updated in the same pull request as the code, and anything it makes stale is deleted.
- Known limitations are recorded in the issue.
- Open questions are answered in the owning doc, or moved to a later issue with a link.
