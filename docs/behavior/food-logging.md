# Food logging

How the user records what they ate. The catalog it matches against is in [the food catalog](food-catalog.md); where the entries are kept is in [data and backup](data-and-backup.md); what unknown levels mean for analysis is in [the analysis rules](../analysis.md#day-level-chemical-exposure-release-1-s5).

## The screen

- The app opens on today. The screen shows one date, and only the user moves it: the previous/next control steps one day at a time, back as far as they like and forward only up to today, and a Today button appears whenever the screen is on another date.
- Any past day can be added to, edited, and deleted from. A future day cannot be opened.
- Today is the phone's calendar date and stays current. It sets the caption (Today, Yesterday, 3 days ago) and where forward stops. When midnight passes or the time zone changes, the screen stays on its date and only the caption and the forward limit change.
- A date that a time zone change makes a future day moves the screen back to today, unless it holds unsaved work. Then the screen stays on it, captioned as later than today, and forward still reaches it from earlier dates, so the work is never stranded. Once nothing on that date is unsaved, future dates are closed again.
- Food typed for a date is saved under that date, however late it is saved.
- When the app returns to the foreground after the date changed while it was away, it opens on today, unless the date on screen has unsaved work, in which case it stays there. A date that changed while the app was in front never moves the screen.
- Unsaved work belongs to the date it was made on. Stepping to another day shows that day's own, and returning brings the first back. It is kept in memory only, so quitting the app discards it.
- A new entry and the edit of a saved line are separate. Tapping a saved line while a new entry is half typed sets the new entry aside, and it returns when the edit is saved, cancelled, or deleted. Changes made to a line stay when the user taps another line, and are dropped only by Cancel, by saving, or by deleting the line.
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

- Each saved piece of text is a line, kept as typed with its time zone, and a day can have several lines, for example breakfast saved when it is eaten and lunch saved later. The screen shows each line as its own numbered entry, with the text as typed above the foods it was matched to.
- Each line keeps its parsed items, each with the catalog food it matched when saved, or none. The match is fixed at save time; chemical levels are looked up later from the food, so research added to the catalog applies to earlier days.
- The user can reopen a line, change the text, and save again, which parses it afresh and replaces the line.
- The user can delete a whole line, or a single item. Deleting an item rewrites the line's text from the items that remain, so the item does not come back when the line is reopened. Deleting a line's last item deletes the line, and deleting an item of the line being edited ends the edit.
- A day with at least one item is a logged day; a day with none is unknown, never a day of eating nothing.

## What is not shown

Chemical levels are not shown on this screen. Looking up a food's level for a chemical returns nothing for a food the catalog does not hold and an unknown for a food with no known level; an unknown never reads as negligible.

## When it fails

- If the catalog cannot be loaded, the screen says so and food logging is unavailable.
- If a save or delete fails, the screen says so, keeps the typed text, and keeps an open edit open.

## Known limitations

- Unsaved text is lost when the app is quit.
- A line whose item was deleted no longer shows the wording the user originally typed; it shows the remaining items, separated by commas.
- A word such as "grilled" is an unrecognized item until the user deletes it and an unrecognized item makes that day's peak unknown for analysis.
- Words the user might type that are not aliases are unrecognized; mapping them to a food is a later change.
