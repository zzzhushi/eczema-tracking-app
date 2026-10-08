# Food logging

How the user records what they ate. The catalog it matches against is in [the food catalog](food-catalog.md); where the entries are kept is in [data and backup](data-and-backup.md); what unknown levels mean for analysis is in [the analysis rules](../analysis.md#day-level-chemical-exposure-release-1-s5).

## The screen

- The app opens on today. A previous/next control steps one day at a time, back as far as the user likes and forward only up to today. A day left on screen as "today" follows the clock past midnight.
- The food section takes one day and nothing else, so the screen hosting it holds no food logic.
- Looking at a day stores nothing; a day is stored by its first saved food.

## Typing and checking

- The user types a line of food, in any wording, across as many lines of text as they like.
- While typing, each piece of the text appears beside the catalog food it matched, or marked "Not recognized". Nothing is saved until the user taps Save.
- Parsing happens on the device by keyword, with no AI model and no network, and gives the same result for the same text and catalog.
- A line that parses to nothing, such as only filler words, cannot be saved.

## How text is parsed

- Text is read as words; commas, other punctuation, and new lines end an item. Case is ignored.
- At each position the longest alias wins, so "chicken thigh" is chicken thigh and not chicken. Aliases are in [the catalog](food-catalog.md#food-file); a plain word shared by several foods is an alias of the default food.
- Filler words ("and", "with", "the", and similar, listed in the catalog data) end an item and are dropped.
- Any other run of words that matches no food is kept as one unrecognized item. Nothing else is dropped, so "grilled chicken" gives an unrecognized "grilled" beside chicken.

## What is kept

- Each saved piece of text is a line, kept as typed with its time zone, and a day can have several lines.
- Each line keeps its parsed items, each with the catalog food it matched when saved, or none. The match is fixed at save time; chemical levels are looked up later from the food, so research added to the catalog applies to earlier days.
- The user can reopen a line, change the text, and save again, which parses it afresh and replaces the line. They can delete a single item, or a whole line. Deleting a line's last item deletes the line.
- A day with at least one item is a logged day; a day with none is unknown, never a day of eating nothing.

## What is not shown

Chemical levels are not shown on this screen. Looking up a food's level for a chemical returns nothing for a food the catalog does not hold and an unknown for a food with no known level; an unknown never reads as negligible.

## When it fails

- If the catalog cannot be loaded, the screen says so and food logging is unavailable.
- If a save or delete fails, the screen says so and keeps the typed text.

## Known limitations

- Reopening a line parses it afresh, so an item the user deleted from it comes back.
- A word such as "grilled" is an unrecognized item until the user deletes it, and an unrecognized item makes that day's peak unknown for analysis.
- Words the user might type that are not aliases are unrecognized; mapping them to a food is a later change.
