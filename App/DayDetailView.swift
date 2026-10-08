import ExzemaCore
import SwiftUI

/// One day's sections. Each feature adds its own section here.
struct DayDetailView: View {
    let model: AppModel

    var body: some View {
        List {
            CheckInSection(model: model)
            Section("Food") {
                Text("Nothing logged").foregroundStyle(.secondary)
            }
        }
    }
}
