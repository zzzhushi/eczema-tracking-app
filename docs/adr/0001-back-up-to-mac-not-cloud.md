# Back up to the user's Mac, not the cloud

**Status**: accepted

## Context

The user requires that the app never transfers health data or skin photos to a cloud on its own; the only exception is an export the user explicitly starts. The app runs under a free developer account that must be reinstalled from a Mac every 7 days.

## Decision

The weekly refresh command reinstalls the app and copies the latest structured-data backup to the Mac, instead of relying on iCloud Backup. Photos are excluded from device and cloud backups and copied to the Mac only when the user asks. The app never sends data off the phone on its own; exports the user starts go where the user picks, with a warning for cloud destinations.

## Consequences

If a weekly refresh is skipped, data since the last one exists only on the phone. Photos are lost with the phone or the app unless an archive was made. A public release would need to revisit cloud destinations for other users.
