# eXzema

A personal eczema tracker that relates what the user eats, applies, and is exposed to against the daily state of their skin, so they can make data-driven decisions about likely triggers. It surfaces patterns in the user's own data and never gives medical advice.

Only terms that are ambiguous or specific to this project are defined here. Rules and thresholds behind them live in the analysis rules.

## Language

### Skin

**Area**:
A body region whose skin is rated separately, such as face or hands.
_Avoid_: Body part, zone

**Check-in**:
The daily record of each area's feel and look, with optional photos; editable through the day.
_Avoid_: Log, journal entry

**Feel**:
The user's 0–10 rating of how an area's skin feels: itch, burning, tightness.
_Avoid_: Itch score, symptoms

**Look**:
A 0–10 rating of how an area's skin appears, given by the user or derived from a photo.
_Avoid_: Severity

**Sign**:
One visible feature scored 0–3 on a photo: redness, dryness or flaking, bumps or blisters, cracks or broken skin, thickening, oozing or crusting.
_Avoid_: Symptom

**Skin score**:
The 1–10 indicator computed from a photo's sign scores, for display only.
_Avoid_: Severity score

**Rating version**:
The model, rubric, and prompt that produced a photo's sign scores; scores compare only within one version.
_Avoid_: Model version

**Normal**:
The level an area is aiming for, set by the user and lowered as the skin recovers.
_Avoid_: Baseline, target

**Flare**:
A period in which an area's look or feel stays 2 or more points above its normal.
_Avoid_: Breakout, outbreak

**Flare onset**:
The start of a worsening, even during a long flare.
_Avoid_: New flare, spike

**Reference photo**:
The photo showing an area's best state so far, replaced only when the user confirms a better one.
_Avoid_: Anchor, best photo

**Treatment**:
A medicated cream or medicine used in response to a flare; it changes how nearby days count as evidence rather than being a suspect.
_Avoid_: Routine item

### Food

**Food**:
Something eaten, as identified in the food catalog.
_Avoid_: Ingredient (reserved for products)

**Food chemical**:
One of the naturally occurring substances rated per food: salicylates, oxalates, amines, histamine, glutamates, nickel.
_Avoid_: Compound, nutrient

**Chemical level**:
A food's coarse rating for one food chemical, from negligible to very high, or unknown.
_Avoid_: Amount, mg value

**Research status**:
Why a chemical level is unknown: not yet researched, researched with no data, or sources conflict.
_Avoid_: Missing, blank

**Peak**:
The highest chemical level among a day's foods for one food chemical, or unknown.
_Avoid_: Maximum, daily level

**Breadth**:
How many of a day's foods sit at moderate or higher for one food chemical; a lower bound when any food is unknown.
_Avoid_: Count, load

**Logged day**:
A day with at least one food entry; a day without one is unknown, never a day of eating nothing.
_Avoid_: Complete day

**Not fresh**:
A meal label for leftovers, food thawed on the counter, or food stored a while.
_Avoid_: Leftovers flag

**Generic food**:
A catalog food standing for a family whose varieties don't differ meaningfully, such as fresh cheese or aged cheese.
_Avoid_: Category

**Suggested food**:
A likely unwritten part of a dish, counted only when the user accepts it.
_Avoid_: Assumed ingredient

**Safe baseline**:
The foods inferred as tolerated from periods of calm skin, adjustable by the user.
_Avoid_: Control diet, normal

**Goal food**:
A food the user wants to reintroduce, such as soy sauce or mushrooms.
_Avoid_: Target food

**Stepping stone**:
A food suggested because it isolates one food chemical on the path to a goal food.
_Avoid_: Challenge food

**Nutrient gap**:
A nutrient the logged foods rarely supply; a prompt to consider testing, never a diagnosis.
_Avoid_: Deficiency

### Products

**Ingredient**:
One component in a product's ingredient list, matched across its aliases.
_Avoid_: Using this word for foods

**Routine**:
The set of product-and-area pairs carried forward each day until the user changes them.
_Avoid_: Regimen

**Background product**:
A product or supplement in constant use, such as shampoo or creatine, recorded once with start and stop dates and never logged daily.
_Avoid_: Shower routine

### Analysis

**Trigger**:
A real-world cause of the user's flares, which the app helps find but never declares.
_Avoid_: Using this word for the app's conclusions

**Suspect**:
A food, food chemical, ingredient, or factor the user's own data links to worse skin, with a confidence.
_Avoid_: Trigger, culprit

**Confidence**:
How strongly the data supports a suspect: strong, suggestive, or too early to tell.
_Avoid_: Probability, certainty

**Common trigger**:
An ingredient or food chemical widely reported to cause reactions, from reference data rather than the user's own history.
_Avoid_: Known trigger

**Factor**:
A daily variable the analysis tests against the skin, such as salicylate peak or sweat load.
_Avoid_: Variable, metric

**Sweat load**:
A day's workout effort adjusted for the heat and humidity at the time and place.
_Avoid_: Exercise level

**Look-back window**:
The days before a change in the skin in which an exposure of a given category can count as its cause.
_Avoid_: Lag, delay

**Natural test**:
The days after a new or reintroduced exposure, treated as an experiment and graded clean, muddied, or unknown.
_Avoid_: Experiment, challenge

**Data coverage**:
The number of logged days a conclusion rests on, always shown beside it.
_Avoid_: Sample size
