# eXzema: analysis rules

The single home for every formula, threshold, and missing-data rule. Other docs link here instead of restating. Numbers marked provisional are recalibrated once real data exists; the worked examples are test oracles.

## Day-level chemical exposure (Release 1, M5)

For each day and food chemical:

- **Analysis levels** are negligible, low, moderate, and high. A catalog level of very high counts as high, so a known high is never understated by an unknown food.
- **Peak** is the highest level among the day's foods. A known high is the peak even if other foods are unknown. A negligible, low, or moderate peak requires every food to have a known level for that chemical; otherwise the peak is unknown.
- **Breadth** is the number of foods at moderate or higher, banded as 1, 2–3, or 4 or more. If any food that day has an unknown level, or a meal was eaten out, breadth is a lower bound ("at least").
- Breadth separates days only when they share a peak and enough days have it, and is ignored when it tracks the number of foods logged per day. The thresholds for both are set before M5 (provisional).
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

## Food-to-skin ranking (Release 1, M5)

To be defined in the M5 issue before M5 coding. The rule must specify:

- **Outcome**: look, feel, or both, and whether it's the level or the change.
- **Comparator**: days without the exposure, or the days before it.
- **Repeated and overlapping exposures**: how consecutive exposure days and overlapping windows are counted.
- **No variation**: what's shown for a food eaten every day, which has nothing to compare against.
- **Minimum samples**: exposed and unexposed day counts before anything is ranked.
- **Coverage and confidence**: the data-coverage figure and the cutoffs for strong, suggestive, and too early to tell.
- **Ties**, plus worked examples for each structural case.

Numbers may start provisional; the structural cases may not.

## Photo rubric and skin score (Release 1, M0 and M4)

- The 0–3 scale follows the per-sign intensity scales of the clinical EASI and SCORAD scores (0 none, 1 mild, 2 moderate, 3 severe), which have been [validated on smartphone photos](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9907712/).
- The six-sign rubric, with a written definition for each level, is a versioned file delivered by the M0 issue.
- A refused or unscorable sign is stored as unscored, never 0.
- The mapping from sign scores (0–18) to the 1–10 skin score, its rounding, how unscored signs affect it, and whether it is the AI's look value are defined in the M4 issue.

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
