# eXzema: analysis rules

The single home for every formula, threshold, and missing-data rule. Other docs link here instead of restating. Numbers marked provisional are recalibrated once real data exists; the worked examples are test oracles.

## Catalog levels (Release 1)

How a food's level for one food chemical is derived from its evidence. The catalog stores the level; the evidence says where it came from.

- **Scale**: negligible, low, moderate, high, very high.
- **Amines**: the sum of tyramine, putrescine, cadaverine, tryptamine, and β-phenylethylamine. Histamine is its own food chemical, and spermidine and spermine, which occur in all foods, are excluded.
- **Histamine**: histamine load as the Swiss Interest Group Histamine Intolerance compatibility score gives it, which combines histamine content, mast cell liberators, and enzyme blockers. Score 0 is negligible, 1 moderate, 2 high, and 3 very high; low is unused. A score of "no general statement possible" or "insufficient information" gives the research status "researched with no data". Measured histamine content and the score's markers go in the note.
- **Normalization**: a source that rates on the same five levels is used as is. A coarser source maps through its chemical's table below and can yield only the levels its bands allow. Negligible requires a source that says so or a measured value near zero. A level is never inferred from a similar food, except that a closely related plant of the same genus may stand in for a food that sources group with it (common chives for garlic chives); that evidence is recorded as converted.
- **Basis**: a level describes the food as usually eaten, per typical serving: the FDA reference amount customarily consumed where one exists, otherwise a USDA household measure. A value measured dry, raw, or per 100 g is converted to that serving. Cooking loss that sources don't measure is not subtracted, so a converted level can be too high and never too low.
- **Source strength**: evidence that needed no form conversion outranks converted evidence, whatever the kind. Within each group, measurement outranks review, then guidance, then list. Only the strongest evidence decides the level; weaker evidence that disagrees goes in the note.
- **Agreement**: entries of the strongest kind within one level of each other give the highest of them. Entries further apart give the research status "sources conflict".
- **Varieties**: varieties within one level of each other share one food at the highest level. Varieties more than one level apart become separate foods, and the plain word matches the default variety. Provisional until several foods have been researched.

### Oxalate cutoffs (mg per serving, provisional)

| Level | mg |
|---|---|
| negligible | under 2 |
| low | 2–4 |
| moderate | 5–9 |
| high | 10–12 |
| very high | 13 or more |

### Nickel cutoffs (µg per serving, provisional)

| Level | µg |
|---|---|
| negligible | under 1 |
| low | 1–9.9 |
| moderate | 10–19.9 |
| high | 20–49.9 |
| very high | 50 or more |

Low, moderate, and high follow a published low-nickel scoring, which spreads a 150 µg daily limit over about 15 servings. The negligible and very high bands extend it.

### Glutamate cutoffs (mg of free glutamate per serving, provisional)

| Level | mg |
|---|---|
| negligible | under 14 |
| low | 14–139 |
| moderate | 140–279 |
| high | 280–699 |
| very high | 700 or more |

The bands use the nickel table's shares of a daily limit, applied to the 30 mg per kg body weight a day European limit for glutamate, about 2.1 g for a 70 kg adult. That limit is set for glutamate as an additive, so the anchor is a judgment.

The other chemicals' tables are added with their first coarse source.

## Day-level chemical exposure (Release 1, S5)

For each day and food chemical:

- **Analysis levels** are negligible, low, moderate, and high. A catalog level of very high counts as high, so a known high is never understated by an unknown food.
- **Peak** is the highest level among the day's foods. A known high is the peak even if other foods are unknown. A negligible, low, or moderate peak requires every food to have a known level for that chemical; otherwise the peak is unknown.
- **Breadth** is the number of foods at moderate or higher, banded as 1, 2–3, or 4 or more. If any food that day has an unknown level, or a meal was eaten out, breadth is a lower bound ("at least").
- Breadth separates days only when they share a peak and enough days have it, and is ignored when it tracks the number of foods logged per day. The thresholds for both are set before S5 (provisional).
- Stored beside each day: foods logged and meals eaten out.

### Worked examples

Levels here are fixtures, not catalog values.

| Day | Foods | Salicylate peak | Breadth |
|---|---|---|---|
| A | oatmeal (negligible), banana (moderate), chicken (negligible), rice (negligible), tomato (high) | high | 2 |
| B | rice (negligible), one food with unknown salicylates | unknown | at least 0 |
| C | rice (negligible), tomato (very high), one food with unknown salicylates | high | at least 1 |

## Look-back windows

| Category | Default window |
|---|---|
| Food chemicals | 0–2 days |
| Contact products | 1–4 days |
| Sweat and heat | 0–1 days |
| Weather and handwashing | build-up over 3 days |

All windows are editable. Release 1 uses only the food window.

## Food-to-skin ranking (Release 1, S5)

To be defined in the S5 issue before S5 coding. The rule must specify:

- **Outcome**: look, feel, or both, and whether it's the level or the change.
- **Comparator**: days without the exposure, or the days before it.
- **Repeated and overlapping exposures**: how consecutive exposure days and overlapping windows are counted.
- **No variation**: what's shown for a food eaten every day, which has nothing to compare against.
- **Minimum samples**: exposed and unexposed day counts before anything is ranked.
- **Coverage and confidence**: the data-coverage figure and the cutoffs for strong, suggestive, and too early to tell.
- **Ties**, plus worked examples for each structural case.

Numbers may start provisional; the structural cases may not.

## Photo rubric and skin score (Release 1, S0 and S4)

- The 0–3 scale follows the per-sign intensity scales of the clinical EASI and SCORAD scores (0 none, 1 mild, 2 moderate, 3 severe), which have been [validated for dermatologists rating smartphone photos](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9907712/); that validation doesn't extend to AI ratings, which S0 found promising against a reference photo but could not yet validate on enough photos ([ADR 0002](adr/0002-user-rating-is-the-measure.md)).
- The seven-sign rubric, with a written definition for each level, is versioned: one file per version in `data/rubric/`.
- Which part of a photo each sign is scored on is part of the rubric, so a change to it is a rubric change.
- A refused or unscorable sign is stored as unscored, never 0.
- When an area has several photos on one day (one per hand, for example), the area's AI skin score is the worse photo's skin score, so a one-sided flare isn't averaged away. Each photo keeps its own scores, so the area can later be split.
- **Look in the analysis is the user's look rating for now.** The AI's skin score is shown beside it and enters the analysis once promoted.
- **Promotion (provisional, to confirm before data is collected)**: the AI skin score may feed the analysis after at least 30 photos with the user's look rating, taken over at least 3 weeks and including at least 3 flare onsets. It must be within 1.5 points of the user's look on at least 80% of photos and rank the photos like the user (rank correlation of at least 0.8). On days the user's look rises 2 or more points above the area's previous 7 days, the AI skin score must do the same at least 80% of the time, and on other days at most 10% of the time. Two photos of the same skin seconds apart must differ by at most 1 point. It is judged on the paired ratings the app already stores, with the recipe unchanged.
- The mapping from sign scores (0–21) to the 1–10 skin score, its rounding, and how unscored signs affect it are defined in the S4 issue. Until promotion, the skin score is the AI's second opinion, for display; it is not a look.

## Later releases (provisional)

### Flare (Release 3)

- **Normal** is a per-area level set by the user. The app proposes lowering it after a week sustained below it.
- **Flare state**: look or feel 2 or more points above normal, however long it lasts.
- **Flare onset**: a rise of 2 or more points above the previous 7 days. Still to define: the trailing statistic (for example, the median), the minimum observed days, whether look and feel are judged separately, and a cooldown so a long worsening doesn't produce an onset every day.

### Product suspicion (Release 3)

- An ingredient's suspicion rises when a product containing it precedes a flare and falls when one is tolerated; tolerance lowers but never clears it.
- Among candidate products, **safest** contains none of the current suspects, and **most informative** splits the current suspects most evenly.
- A reaction on a high-UV day carries a possible-photoallergy note.

### Treatments (Release 4)

A treated day and the 3 days after are excluded from suspect evidence for the treated area (an oral medicine applies to every area) and stay on trends, marked as treated.

### Natural tests (Release 4)

- A natural test begins with a first-time or reintroduced exposure relative to the safe baseline.
- **Muddied** if another discrete logged event falls inside its window: another new or reintroduced food, a new product, ingredient, or routine change, a background-product change, an eaten-out meal, a treatment, or a one-off activity note.
- Weather, sleep, heart rate variability, sweat load, and water exposure never muddy a test; they appear as context.
- **Unknown** if any day in the window has no food entry.

### Nutrient gaps (Release 5)

- A logged day is **covered** for a nutrient by one excellent or two good sources (per typical serving, U.S. food-label definitions: 10–19% and 20% or more of the daily value).
- A nutrient is flagged when covered on fewer than 15 of the last 30 logged days, never before 14 logged days.
- Presence-only: a pinch of a seasoning counts like a serving, so gaps are a heuristic.
