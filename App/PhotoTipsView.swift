import SwiftUI

/// How to take photos that can be compared. Shown before the first photo, and from Settings afterwards.
struct PhotoTipsView: View {
    /// Present when the screen sits in front of the camera; absent when it is opened from Settings.
    var onContinue: (() -> Void)?

    var body: some View {
        List {
            Section("Every photo") {
                Label("Neutral expression, eyes open", systemImage: "face.smiling")
                Label("The same distance and light each time", systemImage: "light.max")
                Label("A plain background", systemImage: "rectangle")
                Label("Hair off the skin", systemImage: "scissors")
                Label("Stay on the camera it opens with: front for your face, back for your hands", systemImage: "camera")
            }
            Section("Close-ups") {
                Label("Fill the frame with a patch of skin about 5 cm across, in focus", systemImage: "viewfinder")
            }
            Section {
            } footer: {
                Text("Photos stay inside eXzema. They are never saved to your Photos library.")
            }
        }
        .navigationTitle("Photo tips")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let onContinue {
                Button(action: onContinue) {
                    Text("Continue to the camera").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
        }
    }
}
