# Photos

How the app takes, files, stores, and shows photos of the user's skin. The privacy boundary is in [the spec](../spec.md#privacy-boundary); the tables are in [data and backup](data-and-backup.md). Nothing here rates a photo: the user's own look and feel ratings stay the measure.

## Slots and kinds

- A photo is of one slot: the face, the left hand, or the right hand. The slots belong to the areas in [skin check-in](skin-check-in.md), and a photo of the left hand is never compared with one of the right.
- A slot takes any number of photos a day, all kept, shown oldest first.
- The face also takes an optional close-up of a patch of skin. A close-up is its own photo, marked as one, with no label, and shows in its own row below the face photos. Hands have no close-up.

## Taking a photo

- Each area's block on the day screen ends in its photo rows: thumbnails and an Add tile per slot, and an Add close-up tile for the face.
- The first Add shows the photo tips (neutral expression and eyes open, the same distance and light, a plain background, hair off the skin, staying on the camera it opens with, and for close-ups a patch about 5 cm across filling the frame). It shows once and is reachable from Settings afterwards.
- The camera is the system camera sheet, opened on the front camera for the face and the back camera for the hands. The sheet lets the user switch, so the camera recorded with a photo is read from the photo's lens metadata and falls back to the one it opened on.
- Camera permission is asked when the user first takes a photo, after the tips. If it is off, the app says so and links to iOS Settings.
- The app has no framing outline or brightness check; keeping photos comparable rests on the tips and the user's own lighting.

## Which day a photo belongs to

- A photo is filed under the day on screen, and only today and yesterday take new photos, so a photo taken just after midnight can still count for the day before. Earlier days show their photos but have no Add tile.
- The real capture time and time zone are always stored. The capture time is the shutter time the camera records, because the camera's Use Photo step can come well after the shutter; the stored zone is the one the shutter time was read in, the camera's recorded offset when given and the phone's zone otherwise, so the viewer shows the local time and day it was taken. Without a readable shutter time the capture time is when the photo was saved, in the phone's zone. When a photo is filed under a different day than it was taken on, the viewer says so.
- The first photo on a day creates the day.
- Photos come only from the in-app camera; nothing is imported from the Photos library.

## Storage

- A photo's image is a JPEG file in the app's private storage, in a `Photos` directory beside the store; the store holds a record with its day, slot, kind, camera, capture time, time zone, and file name.
- Images are downscaled to about 1600 px on the long side, rotated upright, and stripped of all camera metadata, including location.
- Files are protected until the first unlock after a restart, excluded from device and cloud backups, and never written to the Photos library. Temporary files from the camera are not kept.
- Resizing and writing a captured photo run in the background after the camera closes, under a background task so leaving the app does not stop them; a "Saving photo…" row shows until each is stored, and its thumbnail then appears. The captured image exists only in memory until then, and iOS limits how long the task may run. If the photo directory cannot be opened, the day screen says so and offers no Add tiles.
- A record and its file are added and removed together. Files with no record are removed when the app starts.
- Deleting a day deletes its photo records, and the next start removes their files.

## Viewing and deleting

- Tapping a thumbnail opens the photo full screen. Pinching or double tapping zooms, swiping moves between that slot's photos for the day, and the bar shows the slot, the time taken, and where the day differs.
- Each thumbnail is announced to VoiceOver with its slot, its kind, and the time taken, so photos in a row can be told apart.
- Delete asks first, then removes the file and its record. The day stays.
- Whenever the app is not active, every photo on screen, thumbnails and the viewer, is replaced by a placeholder, so the app switcher never shows skin.

## Getting photos off the phone

The photos reach the user's Mac only when the pull script copies them, with the store and logs, into its output folder ([data and backup](data-and-backup.md#diagnostics)). The copy is not encrypted by the app; the Mac's disk encryption is the only protection there.

## Limits

- Until backup to the Mac exists, photos live only in the app and in whatever the pull script copied. Deleting the app deletes them.
- A screenshot taken in the app goes to the Photos library, outside the app's control.
- In debug builds on a device with no camera, such as the simulator, the camera step adds a generated image instead.
