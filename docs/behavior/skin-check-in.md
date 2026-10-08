# Skin check-in

How the user opens a day and rates their skin. The ownership of unknown values is in [the spec](../spec.md#data-principles); the terms are in [the glossary](../../CONTEXT.md).

## Day screen

- The home screen shows a week strip over the selected day. A week runs Monday to Sunday and the strip pages back one week at a time.
- A fresh launch selects today, the local calendar date shown on the phone. Any past day can be selected and edited.
- A day after today is shown dimmed and cannot be selected.
- A dot under a date means the day has a saved row; browsing a day never creates one.
- When the app becomes active after the date has changed, the selection moves to the new today only if it was on today. A past day being edited stays selected.
- The strip reaches back about twenty years. Its text stops growing with the system text size at the largest ordinary setting, so every date stays visible.

## Check-in

- Each active area has two ratings, feel and look, each 0 to 10. The app starts with two areas, face and hands.
- Feel is described as itch, burning, tightness, pain, and look as redness, dryness, cracks, bumps. Both show the anchors 0 clear, 3 mild, 6 moderate, 10 worst ever.
- A rating is one of eleven buttons with none selected until the user taps one. Tapping the selected value clears it back to unknown. At accessibility text sizes the buttons wrap onto two rows.
- Every rating saves as soon as it is tapped, with no submit step. The latest value is the day's value, and only the latest value and when it changed are kept.
- A rating that was never given is unknown, never 0. A day or area with no ratings is unknown.
- The first rating on a day creates that day, in the phone's time zone at that moment. A day that already exists keeps the time zone it was first saved in.
- Clearing a rating that was never given changes nothing.
