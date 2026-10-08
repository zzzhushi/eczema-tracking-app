# Data and backup

Where the app keeps its data, what survives, and what does not. The principles are in [the spec](../spec.md#data-principles); the storage decision is in [ADR 0003](../adr/0003-store-in-sqlite-through-grdb.md).

## The store

- One SQLite file in a dedicated directory under the app's private storage. The schema version is the file's `user_version`.
- The store holds days: a local calendar date and the time zone it was logged in. A day runs midnight to midnight in the phone's time zone and is never derived from UTC.
- A day holds skin check-ins, one row per area with its feel and look, and is created by the first rating on it. Location captures are separate rows with their own date and time zone ([check-in](skin-check-in.md), [location](environment-and-health.md#location-capture)).
- The file is encrypted at rest with the iOS default protection, available once the phone has been unlocked after a restart.
- The store's directory is excluded from device and iCloud backups. Nothing from the app reaches the cloud.
- Opening a store written by a newer schema is refused and leaves the file untouched.

## What survives

| Event | Data |
|---|---|
| Relaunch | Kept |
| Installing an updated build over the app, including the 7-day refresh | Kept, as long as the bundle identifier and signing team stay the same |
| Deleting the app | **Lost.** The data lives in the app's own storage and is in no backup |
| Losing or wiping the phone | **Lost** until backup to the Mac exists (Release 2); the structured export (S6) is the only copy |

## Diagnostics

Crash and hang reports delivered by the system are saved as JSON files in a dedicated directory, excluded from backup. They are read by downloading the app container from Xcode's Devices window. Nothing is sent anywhere.

Crash reports arrive at the next launch and are saved reliably. Hang reports use the same save path, but no hang report has yet been delivered, so hang collection is unverified ([#33](https://github.com/zzzhushi/eczema-tracking-app/issues/33)).
