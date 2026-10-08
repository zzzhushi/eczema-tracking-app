import ExzemaCore
import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    #if DEBUG
    @State private var confirmingClearAll = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                if let failure = model.failure {
                    Text(failure).foregroundStyle(.red)
                }
                Section("Your data") {
                    Text(DataNote.deletion)
                }
                Section {
                } footer: {
                    Text(BuildInfo(stamp: BuildStamp.value).label)
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if DEBUG
            .confirmationDialog("Delete every saved day?", isPresented: $confirmingClearAll, titleVisibility: .visible) {
                Button("Delete all days", role: .destructive) { model.clearAll() }
            }
            #endif
        }
    }
}
