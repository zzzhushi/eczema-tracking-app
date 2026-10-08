# Permissions and settings

What the app asks the user to allow, and the screens where they review it.

## First launch

- The first launch shows one full screen with a Continue button. It states that the app finds patterns in the user's own data and does not give medical advice, that the data stays on the phone and is not backed up so deleting the app deletes it, and that the app notes an approximate location while in use.
- Continue records that the screen was seen and then asks for location permission. The screen does not appear again.
- The flag is an app preference kept in `UserDefaults`, not in the store. It is lost with the data when the app is deleted.

## Location permission

- The app asks for location only while it is in use, never always, and asks once, after the first-launch screen.
- If the user declines, the app records no location and does not ask again.
- Settings shows whether location is not yet asked, on while using the app, or off, with a link to iOS Settings once the user has answered.

## Settings

Settings opens from the gear on the home screen and holds:

- the note that deleting the app deletes its data;
- the location status and the explanation of what is recorded;
- the build time, which identifies the installed build;
- in debug builds only, the debug tools.
