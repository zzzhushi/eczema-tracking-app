# Data and backup

Where the app keeps its data, what survives, and what does not. The principles are in [the spec](../spec.md#data-principles); the storage decision is in [ADR 0003](../adr/0003-store-in-sqlite-through-grdb.md).

## The store

- One SQLite file in a dedicated directory under the app's private storage. The schema version is the file's `user_version`.
- The store holds days: a local calendar date and the time zone it was logged in. A day runs midnight to midnight in the phone's time zone and is never derived from UTC.
- A day is stored on its first write, never by looking at it.
- Food is stored as lines and items. A line is a piece of typed text with its time zone; its items are the parsed pieces, each with the catalog food ID it matched when saved, or none if unrecognized. A line always has at least one item. Deleting a day deletes its food.
- Skin check-ins are one row per area with its feel and look, and the first rating on a day creates the day. Location captures are separate rows with their own date and time zone ([check-in](skin-check-in.md), [location](environment-and-health.md#location-capture)).
- The file is encrypted at rest with the iOS default protection, available once the phone has been unlocked after a restart.
- The store's directory is excluded from device and iCloud backups. Nothing from the app reaches the cloud.
- Opening a store written by a newer schema is refused and leaves the file untouched.

## Schema versions

| Version | Adds | Migration |
|---|---|---|
| 1 | `day` | Creates the table. |
| 2 | `food_line`, `food_item` | Creates two tables and their indexes. No existing row is read or changed, so days saved under version 1 are kept. |
| 3 | `area`, `check_in`, `location_capture` | Creates three tables and seeds the face and hands areas. No existing row is read or changed, so days and food saved earlier are kept. |
| 4 | `location_capture.placeName` | Adds one empty column. Captures saved earlier are named the next time the app looks them up. |

Every migration is a named, ordered step that only adds to or reshapes the store and never wipes it. Each version has a committed fixture store, and a test opens every fixture, migrates it, and reads it back.

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
