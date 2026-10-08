import ExzemaCore
import SwiftUI

/// The places recorded for the shown date; hidden when nothing was captured, since that is unknown.
struct LocationSection: View {
    let model: AppModel

    var body: some View {
        if model.places.captureCount > 0 {
            Section("Location") {
                if model.places.names.isEmpty {
                    Text("Recorded. The city name is not available yet.").foregroundStyle(.secondary)
                } else {
                    Text(model.places.names.joined(separator: " · "))
                }
            }
        }
    }
}
