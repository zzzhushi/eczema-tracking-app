# Data

Reference content the app reads. Each fact lives in one hand-edited file; nothing here is copied into docs, and review tables are generated, never committed.

- `sources.json`: bibliography entries (title, authors, year, journal, DOI, URL, accessed date), written once and referenced by ID. A source the food catalog cites also carries a `kind` (measurement, review, guidance, or list).
- `rubric/v1.json`: the photo-rating rubric. One file per version. Once a version has rated stored photos, a change to a definition, sign, the scale, or the scoring rule creates a new version; until then the version is edited in place. A sign may add a `lookFor` note that applies to every level, and `sources` for the research its levels are based on.
- `catalog/foods/<id>.json` and `catalog/manifest.json`: the food catalog, one file per food. The format and its checks are in [the food catalog behavior doc](../docs/behavior/food-catalog.md); the rules that turn evidence into a level are in [the analysis rules](../docs/analysis.md#catalog-levels-release-1).

Nothing personal goes in this folder: the user's own overrides, routines, and logs live in the app on the phone.

## Validation

Tests in `ExzemaCore` load the whole dataset and check the catalog rules, that every cited source exists, and, once the rubric is loaded, that every rubric has a scoring rule and the seven signs with levels 0–3. Run them with `swift test --package-path ExzemaCore`.

## Review

```
python3 scripts/review_table.py data/rubric/v1.json
python3 scripts/review_table.py data/catalog
```

print a readable table for a pull request description.
