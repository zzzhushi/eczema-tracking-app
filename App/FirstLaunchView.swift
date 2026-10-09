import SwiftUI

struct FirstLaunchView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Text("eXzema").font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 16) {
                Text("It finds patterns in your own data. It does not give medical advice.")
                Text(DataNote.deletion)
                Text(DataNote.location)
            }
            .font(.title3)
            Spacer()
            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
    }
}

enum DataNote {
    static let location = "While you use eXzema it notes your approximate location, rounded to about 11 km. The rounded position is sent to Apple's maps service to find the city name, and later to look up weather."
    static let photos = "Photos stay inside eXzema, protected by your passcode. They are not saved to your Photos library or backed up."
    static let deletion = "Your data stays on this phone and is not backed up. Deleting the app deletes its data."
}
