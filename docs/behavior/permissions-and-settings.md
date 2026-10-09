# Permissions and settings

What the app asks the user to allow, and the screens where they review it.

## First launch

- The first launch shows one full screen with a Continue button. It states that the app finds patterns in the user's own data and does not give medical advice, that the data stays on the phone and is not backed up so deleting the app deletes it, and that the app notes an approximate location while in use and sends the rounded position to Apple's maps service to find the city name.
- Continue records that the screen was seen and then asks for location permission. The screen does not appear again.
- The flag is an app preference kept in `UserDefaults`, not in the store. It is lost with the data when the app is deleted.

## Location permission

- The app asks for location only while it is in use, never always, and asks once, after the first-launch screen.
- If the user declines, the app records no location and does not ask again.
- Settings shows whether location is not yet asked, on while using the app, or off. While it is not yet asked, which also follows an Allow Once answer, an Allow location button asks again; after an answer it links to iOS Settings.

## Camera permission

- The app asks for the camera only when the user first takes a photo, after the photo tips ([photos](photos.md#taking-a-photo)).
- If it is off, taking a photo shows a message with a link to iOS Settings; nothing is recorded.

## Settings

Settings opens from the gear on the home screen and holds:

- the note that deleting the app deletes its data;
- the location status and the explanation of what is recorded;
- the photo tips, and a note that photos stay inside the app;
- the build time, which identifies the installed build;
- in debug builds only, the debug tools.
