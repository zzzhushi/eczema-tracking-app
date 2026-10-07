# Data

Reference content the app reads. Each fact lives in one hand-edited file; nothing here is copied into docs, and review tables are generated, never committed.

- `sources.json`: bibliography entries (title, authors, year, journal, DOI, URL, accessed date), written once and referenced by ID.
- `rubric/v1.json`: the photo-rating rubric. One file per version; a change to a definition, sign, or the scale creates a new version.
- `catalog/foods.json`: the food catalog (added with the first catalog research).

Nothing personal goes in this folder: the user's own overrides, routines, and logs live in the app on the phone.

## Catalog entry shape

Each chemical has one assessment: a result, plus the evidence behind it.

```json
{
  "id": "oatmeal",
  "name": "Oatmeal",
  "aliases": ["oats", "rolled oats"],
  "chemicalAssessments": {
    "salicylates": {
      "result": { "kind": "known", "level": "low" },
      "evidence": [{ "sourceId": "…", "locator": "Table 2", "basis": "Raw oats, per 100 g" }],
      "note": "Mapped to the catalog's low band"
    },
    "amines": {
      "result": { "kind": "unknown", "reason": "not-yet-researched" },
      "evidence": []
    }
  },
  "allergens": []
}
```

- A result is `known` (with a level: negligible, low, moderate, high, very high) or `unknown` (with a reason: `not-yet-researched`, `no-data-found`, or `sources-conflict`).
- Every known result has evidence; locator and basis are optional.

## Validation

Tests load the whole dataset and check that IDs and aliases are unique, every enum decodes, every known result has evidence, every cited source exists, every food has every chemical and allergen field, and every rubric has the seven signs with levels 0–3.

## Review

```
python3 scripts/review_table.py data/rubric/v1.json
```

prints a readable table for a pull request description.
