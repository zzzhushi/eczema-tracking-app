# Environment and health

The context that sits beside a day's food and skin. Only location capture exists so far; later releases add weather, air quality, and health data.

## Location capture

- When the app becomes active and the user has allowed location while in use, it records one rounded location, unless the newest stored capture is less than an hour old.
- Only one capture runs at a time; a trigger that arrives while one is in progress is dropped.
- The hour runs from the newest stored capture. A request that returns no location writes nothing and does not start a wait, so the next activation tries again.
- A phone clock set back before the newest capture counts as due.
- Coordinates are rounded to 0.1° (about 11 km) before they are stored, as whole tenths of a degree. Halves round away from zero.
- Each capture records the instant, the local calendar date, and the time zone at that moment. The date is the phone's local date, never derived from UTC.
- A coordinate outside the valid range is dropped.
- A capture is not tied to a day and never creates one. Deleting days leaves captures in place.
- A day with no capture is not filled in here; later releases decide a day's place when the analysis runs.
- Coordinates and place names are never written to the log.

## Place names

- Each capture is given the name of the city its rounded position falls in, looked up with Apple's maps service. The lookup sends only the rounded position, never the exact one.
- A position that already has a name is reused without a lookup, so one lookup serves every capture at the same rounded place.
- A lookup that returns nothing, such as without a network, leaves the capture unnamed and a later pass tries again. A capture without a name is still a capture.
- Names are kept with the capture and shown offline. A zip code is not looked up: 11 km can span many of them.
- The day screen lists the distinct cities captured on the shown date, in the order they were first visited. A date with captures but no names says the name is not available yet, and a date with no captures shows nothing.
