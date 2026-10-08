# Food catalog

The bundled reference data that says what each food is, what it is called, and how much of each food chemical it carries. Principles are in [the spec](../spec.md#food-catalog); how a level is derived is in [the analysis rules](../analysis.md#catalog-levels-release-1).

## Contents

`data/catalog/` holds the only copy of every food, alias, allergen tag, level, and citation reference. Other docs link to it and never restate it.

- `catalog/foods/<id>.json`: one file per food.
- `data/sources.json`: the shared bibliography, one record per source.
- `catalog/filler-words.json`: words typed between foods, such as "and" and "with", that matching drops instead of keeping as unrecognized entries. One lowercase word each, never an alias.
- `catalog/manifest.json`: `schemaVersion` changes with the file format; `catalogVersion` increases in any change to foods, aliases, or levels.

## In the app

The app bundles `data/catalog/` and `data/sources.json` from the repository, never a copy kept elsewhere, and loads them at launch through the loader, whose checks must pass. If the catalog cannot be loaded, the app says so on screen and logs a fault; it never continues with an empty catalog. CI compares the built app's bundled data with the repository's.

## Food file

| Field | Meaning |
|---|---|
| `id` | Stable kebab-case key, never reused. |
| `name`, `description` | Display name and what the entry covers (form, freshness). |
| `aliases` | Lowercase words that match the food in typed text, unique across the catalog. An alias names the food alone: a composite or prepared dish that adds other ingredients, such as a matcha latte or scrambled eggs, is not an alias. A plain word that several foods share, such as "chicken" or "coffee", is an alias of the one default food. |
| `varieties` | Kinds researched under this food, at most one `default`. A variety is never chosen when logging. |
| `allergens` | From a fixed list: milk, egg, fish, crustacean-shellfish, tree-nuts, peanuts, wheat, soy, sesame. |
| `serving` | The typical serving the levels describe. |
| `chemicals` | Salicylates, oxalates, amines, histamine, glutamates, and nickel, each a result with its evidence. |

### Serving

A serving has a `description`, its `grams`, and an `origin`: `fda-racc` (an FDA reference amount), `usda-household` (a USDA household measure), or `estimate`. Unless it is an estimate, it names its `sourceId` and `locator`. When the reference gives a household measure without a weight, `weightSourceId` and `weightLocator`, always given together, cite where the grams come from, and a `note` says how they were converted. An estimate carries a note saying why no reference exists.

## Result and evidence

A result is either `known` with a level (negligible, low, moderate, high, or very high) or `unknown` with a reason: `not-yet-researched`, `researched-no-data`, or `sources-conflict`.

Evidence is a list of entries, each with:

- a `sourceId` and a `locator` inside the source;
- the `basis` the source measured (for example "dry weight, per 100 g");
- the `kind` of support that entry gives, set per entry because one source can support different claims differently: `measurement` (a paper or monitoring data that measured the food), `review` (a peer-reviewed compilation that cites measurements), `guidance` (an institutional document or clinical list), or `list` (any other compilation);
- the `level` that entry maps to;
- `foodMatch` (`related` when the source rates a closely related plant or food that stands in; absent means exact) and `formMatch` (`converted` when the source measured a different form than the entry describes, such as dry weight for cooked food; absent means exact);
- optional `markers`, SIGHI's own flags from a fixed set, kept so a level can show why: H (histamine content), H! (perishable, forms histamine quickly), A (other amines), L (mast cell liberator), B (enzyme blocker), and ? (SIGHI's own assessment);
- an optional `note`.

A source that gives no level for the food, such as a diet that merely allows or forbids it, is not evidence. A chemical may also carry a `note` explaining its result. A level whose strongest evidence is `guidance` or `list` is flagged for review.

## Sources

Each record in `data/sources.json` is bibliographic only: an `id`, title, authors, year, journal or publisher, DOI or URL, and the date accessed.

## Checks

The loader refuses a manifest whose `schemaVersion` it does not read, and refuses the catalog unless all of these hold:

- IDs are unique, source IDs are unique, and no alias belongs to two foods.
- Every food has all six chemicals, and every allergen is on the fixed list.
- A known result has at least one evidence entry, and a `sources-conflict` result has at least two.
- A result follows from its evidence under [the catalog-level rules](../analysis.md#catalog-levels-release-1).
- Every cited source exists, including those cited by servings.
- A serving that is not an estimate names a source and locator; an estimate carries a note; a weight citation has both its source and locator.
- A food with any known level has a serving.
- The manifest decodes, and every marker is in the fixed set.
