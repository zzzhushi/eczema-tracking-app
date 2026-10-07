import ExzemaCore
import SwiftUI

struct DayListView: View {
    let model: AppModel
    @State private var confirmingClearAll = false

    var body: some View {
        NavigationStack {
            List {
                if let failure = model.failure {
                    Text(failure).foregroundStyle(.red)
                }
                Section("Saved days") {
                    if model.days.isEmpty {
                        Text("No days saved yet").foregroundStyle(.secondary)
                    }
                    ForEach(model.days, id: \.date) { day in
                        VStack(alignment: .leading) {
                            Text(day.date.isoString)
                            Text(day.timeZoneIdentifier).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                #if DEBUG
                Section("Debug") {
                    Button("Save today") { model.saveToday() }
                    Button("Clear today", role: .destructive) { model.clearToday() }
                    Button("Clear all days", role: .destructive) { confirmingClearAll = true }
                    Button("Crash now", role: .destructive) { DebugActions.crash() }
                    Button("Hang for 5 seconds") { DebugActions.hang() }
                }
                #endif
            }
            .navigationTitle("eXzema")
            .confirmationDialog("Delete every saved day?", isPresented: $confirmingClearAll, titleVisibility: .visible) {
                Button("Delete all days", role: .destructive) { model.clearAll() }
            }
        }
    }
}
