# eXzema

A personal eczema tracker that relates what the user eats, applies, and is exposed to against the daily state of their skin, so they can make data-driven decisions about likely triggers. It surfaces patterns in the user's own data and never gives medical advice.

## Language

### Skin

**Area**:
A body region whose skin is rated separately, such as face or hands.
_Avoid_: Body part, zone, location

**Check-in**:
The once-daily record of each area's feel and look, with optional photos, treatments, and notes; editable through the day.
_Avoid_: Log, journal entry, survey

**Feel**:
The user's 0–10 rating of how an area's skin feels: itch, burning, tightness.
_Avoid_: Itch score, symptoms

**Look**:
A 0–10 rating of how an area's skin appears, given either by the user or derived from a photo rating.
_Avoid_: Severity, appearance score

**Flare**:
A period in which an area's ratings rise above its usual level.
_Avoid_: Breakout, outbreak, episode

**Sign**:
One visible feature of eczema scored 0–3 in a photo rating: redness, dryness or flaking, bumps or blisters, cracks or broken skin, thickening, oozing or crusting.
_Avoid_: Symptom, feature

**Photo rating**:
The AI's sign scores for one photo of one area, plus the skin score derived from them.
_Avoid_: AI score, analysis

**Photo comparison**:
The AI's description of what changed between a photo and the previous photo of the same area.
_Avoid_: Diff, delta

**Skin score**:
The 1–10 indicator derived from a photo rating's sign scores, for display only.
_Avoid_: Severity score, grade

**Rating version**:
The combination of model, rubric, and prompt that produced a photo rating; ratings are comparable only within one version.
_Avoid_: Model version

**Treatment**:
A medicated cream or medicine used in response to a flare, recorded on each day it is used.
_Avoid_: Medication product, routine item

### Food

**Food**:
Something eaten, as identified in the food catalog.
_Avoid_: Ingredient (reserved for products), item

**Meal**:
An optional grouping of a day's foods that carries a source and a not-fresh label.
_Avoid_: Entry, plate

**Source**:
Where a meal came from: home-made, eaten out, or packaged.
_Avoid_: Origin, restaurant flag

**Not fresh**:
A meal label for leftovers, food thawed on the counter, or food stored a while.
_Avoid_: Leftovers flag, stale

**Food catalog**:
The bundled reference of foods, each with chemical levels and allergen tags and a citation for each level.
_Avoid_: Food database, RPAH list

**Generic food**:
A catalog food standing for a family whose varieties do not differ meaningfully in chemistry, such as fresh cheese or aged cheese.
_Avoid_: Default food, category

**Food chemical**:
One of the naturally occurring substances rated per food: salicylates, oxalates, amines, histamine, glutamates, nickel.
_Avoid_: Compound, nutrient, trace chemical

**Chemical level**:
A food's coarse rating for one food chemical: negligible, low, moderate, high, very high, or unknown; unknown is never treated as negligible.
_Avoid_: Amount, mg value, score

**Allergen tag**:
The presence of one of nine common food allergens in a food: milk, egg, wheat, soy, peanut, tree nuts, fish, shellfish, sesame.
_Avoid_: Allergy flag

**Suggested food**:
A food the AI proposes as a likely unwritten part of a dish, counted only when the user accepts it.
_Avoid_: Assumed ingredient, inferred food

**Goal food**:
A food the user wants to reintroduce, such as soy sauce or mushrooms.
_Avoid_: Target food, wishlist

**Safe baseline**:
The foods inferred as tolerated from periods of calm skin, adjustable by the user.
_Avoid_: Control diet, safe list

**Stepping stone**:
A food suggested because it isolates one food chemical on the path to a goal food.
_Avoid_: Challenge food, test food

**Nutrient source**:
A food that supplies a nutrient at the good (10–19% of the daily value) or excellent (20% or more) level in a typical serving.
_Avoid_: Rich food, nutrient amount

**Covered day**:
A logged day that included one excellent or two good sources of a given nutrient.
_Avoid_: Nutrient day, intake day

**Nutrient gap**:
A nutrient covered on fewer than half of the last 30 logged days; a prompt to consider testing, never a diagnosis.
_Avoid_: Deficiency, shortfall

### Products

**Product**:
Something applied to the skin, defined by its ingredient list.
_Avoid_: Item, cosmetic

**Ingredient**:
One component in a product's ingredient list, matched across its aliases.
_Avoid_: Using this word for foods

**Routine**:
The set of product-and-area pairs carried forward each day until the user changes them.
_Avoid_: Regimen, schedule

**One-off use**:
A product used on a day without adding it to the routine.
_Avoid_: Ad-hoc product, temporary product

**Product library**:
Every product the user has ever recorded, kept permanently.
_Avoid_: Product list

**Quick picks**:
The short, recency- and frequency-ordered selection offered when changing a routine; leaving it never removes a product from the library.
_Avoid_: Favorites, recents

**Background product**:
A product in constant contact with the skin, such as shampoo or detergent, recorded once with a start date and never logged daily.
_Avoid_: Shower routine, passive product

### Environment and health

**Exposure**:
Anything encountered on a day that might affect the skin: a food, a product use, weather, an activity.
_Avoid_: Input, event

**Factor**:
A daily variable the analysis tests against flares, such as salicylate level, sweat load, or UV index.
_Avoid_: Variable, feature, metric

**Core factor**:
A factor chosen in advance for testing; only core factors appear in ranked results.
_Avoid_: Main factor, primary metric

**Sweat load**:
A day's workout minutes weighted by intensity and adjusted for the heat and humidity at the time and place.
_Avoid_: Exercise level, activity score

**Water exposure**:
Time in a pool, the ocean, or a hot tub, from swim workouts or notes.
_Avoid_: Swimming flag

**Note**:
Free text about a day's one-off activities, such as painting or cleaning, surfaced in flare investigations.
_Avoid_: Comment, misc field

**Signs of strain**:
The daily health summary of sleep, heart rate variability, and resting heart rate; a curiosity, never a factor.
_Avoid_: Stress score, stress level

### Analysis

**Trigger**:
A real-world cause of the user's flares, which the app helps find but never declares.
_Avoid_: Using this word for the app's conclusions

**Suspect**:
A food, food chemical, ingredient, or factor the user's own data links to flares, with a confidence.
_Avoid_: Trigger, culprit, cause

**Confidence**:
How strongly the data supports a suspect: strong, suggestive, or too early to tell.
_Avoid_: Probability, certainty, risk

**Common trigger**:
An ingredient or food chemical widely reported to cause reactions, from bundled reference data rather than the user's own history.
_Avoid_: Known trigger, allergen

**Look-back window**:
The days before a flare in which an exposure of a given category can count as its cause.
_Avoid_: Lag, window, delay

**Natural test**:
The days after a new or reintroduced exposure, treated as an experiment and graded clean or muddied.
_Avoid_: Experiment, challenge, trial

**Clean**:
A natural test in which the tested exposure was the only new thing and no meal was eaten out.
_Avoid_: Valid, controlled

**Muddied**:
A natural test in which something else changed during its window; it still counts, as weaker evidence.
_Avoid_: Invalid, failed, contaminated

**Product check**:
The "should I try this?" assessment of a product's ingredients against suspects and common triggers.
_Avoid_: Risk scan, compatibility check

**Flare investigation**:
The "why did this flare happen?" view listing what was different in the look-back windows before a flare.
_Avoid_: Root cause, diagnosis

**Safest**:
Among product candidates, the one containing none of the user's current suspects.
_Avoid_: Recommended, best

**Most informative**:
Among product candidates, the one whose outcome would most narrow the suspect list.
_Avoid_: Riskiest, test product

**Data coverage**:
The number of logged days a conclusion rests on, always shown beside it.
_Avoid_: Sample size, completeness

**Logged day**:
A day with at least one food entry; a day without one is unknown, never a day of eating nothing.
_Avoid_: Complete day, finished day

### Operations

**Weekly refresh**:
The command run on the user's Mac that reinstalls the app before its free signing expires and copies the latest backup off the phone.
_Avoid_: Re-sign, redeploy, sync
