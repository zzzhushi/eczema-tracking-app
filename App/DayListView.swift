import ExzemaCore
import SwiftUI

struct DayListView: View {
    let model: AppModel

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
                            Text("\(day.date.year)-\(day.date.month, format: .number.precision(.integerLength(2)))-\(day.date.day, format: .number.precision(.integerLength(2)))")
                            Text(day.timeZoneIdentifier).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                #if DEBUG
                Section("Debug") {
                    Button("Save today") { model.saveToday() }
                    Button("Crash now", role: .destructive) { DebugActions.crash() }
                    Button("Hang for 5 seconds") { DebugActions.hang() }
                }
                #endif
            }
            .navigationTitle("eXzema")
        }
    }
}
