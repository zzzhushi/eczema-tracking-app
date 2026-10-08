import ExzemaCore
import SwiftUI

/// One day's sections. Each feature adds its own section here.
struct DayDetailView: View {
    let date: LocalDate
    let isToday: Bool

    var body: some View {
        List {
            Section("Skin check-in") {
                Text("Not rated").foregroundStyle(.secondary)
            }
            Section("Food") {
                Text("Nothing logged").foregroundStyle(.secondary)
            }
        }
    }
}
