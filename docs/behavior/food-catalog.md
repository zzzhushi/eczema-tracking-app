# Food catalog

The bundled reference data that says what each food is, what it is called, and how much of each food chemical it carries. Principles are in [the spec](../spec.md#food-catalog); how a level is derived is in [the analysis rules](../analysis.md#catalog-levels-release-1).

## Contents

`data/catalog/` holds the only copy of every food, alias, allergen tag, level, and citation. Other docs link to it and never restate it.

- `foods/<id>.json`: one file per food.
- `sources.json`: one record per cited source.
- `manifest.json`: `schemaVersion` changes with the file format; `catalogVersion` increases in any change to foods, aliases, or levels.

## Food file

| Field | Meaning |
|---|---|
| `id` | Stable kebab-case key, never reused. |
| `name`, `description` | Display name and what the entry covers (form, freshness). |
| `aliases` | Lowercase words that match the food in typed text, unique across the catalog. |
| `varieties` | Kinds researched under this food, at most one `default`. A variety is never chosen when logging. |
| `allergens` | From a fixed list: milk, egg, fish, crustacean-shellfish, tree-nuts, peanuts, wheat, soy, sesame. |
| `serving` | The typical serving the levels describe: `description`, `grams`, and `origin` (`fda-racc` or `usda-household`). Null until researched. |
| `chemicals` | Salicylates, oxalates, amines, histamine, glutamates, and nickel, each a result with its evidence. |

## Result and evidence

A result is either `known` with a level (negligible, low, moderate, high, or very high) or `unknown` with a reason: `not-yet-researched`, `researched-no-data`, or `sources-conflict`.

Evidence is a list of entries, each with a `sourceId`, a `locator` inside the source, the `basis` the source measured (for example "dry weight, per 100 g"), the `level` that entry maps to, an optional `converted` flag for a measurement in a different form than the entry describes (for example dry weight for cooked food), and an optional `note`. A source that gives no level for the food, such as a diet that merely allows or forbids it, is not evidence. A chemical may also carry a `note` explaining its result.

## Sources

Each record has an `id`, a `kind`, bibliographic fields (title, authors, year, publisher, DOI or URL), and the date accessed. The kind is the strength of the source:

1. `measurement`: a paper or monitoring data that measured the food.
2. `review`: a peer-reviewed compilation that cites measurements.
3. `guidance`: an institutional document or clinical list.
4. `list`: any other compilation.

A level whose strongest evidence is `guidance` or `list` is flagged for review.

## Checks

The catalog loads only if all of these hold:

- IDs are unique, and no alias belongs to two foods.
- Every food has all six chemicals, and every allergen is on the fixed list.
- A known result has at least one evidence entry, and a `sources-conflict` result has at least two.
- A result follows from its evidence under [the catalog-level rules](../analysis.md#catalog-levels-release-1).
- Every cited source exists.
- A food with any known level has a serving.
- The manifest decodes.
