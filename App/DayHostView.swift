import ExzemaCore
import SwiftUI

/// Opens on today and steps back through earlier days; the food section does all the food work.
struct DayHostView: View {
    let model: AppModel
    @State private var selection = DaySelection()
    #if DEBUG
    @State private var confirmingClearAll = false
    #endif

    var body: some View {
        let day = selection.day(now: Date(), in: .current)
        NavigationStack {
            List {
                if let failure = model.failure {
                    Text(failure).foregroundStyle(.red)
                }
                if let catalogFailure = model.catalogFailure {
                    Text(catalogFailure).foregroundStyle(.red)
                }
                Section {
                    HStack {
                        Button { selection.goBack() } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Previous day")
                        Spacer()
                        VStack {
                            Text(day.date.isoString).font(.headline)
                            Text(caption(for: selection)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { selection.goForward() } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Next day")
                            .disabled(!selection.canGoForward)
                    }
                    .buttonStyle(.borderless)
                }
                FoodSectionView(day: day)
                    .id(model.dataVersion)
                Section {
                } footer: {
                    Text(BuildInfo(stamp: BuildStamp.value).label)
                }
                #if DEBUG
                Section("Debug") {
                    Button("Clear today", role: .destructive) { model.clearToday() }
                    Button("Clear all days", role: .destructive) { confirmingClearAll = true }
                    Button("Crash now", role: .destructive) { DebugActions.crash() }
                    Button("Hang for 5 seconds") { DebugActions.hang() }
                }
                #endif
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("eXzema")
            #if DEBUG
            .confirmationDialog("Delete every saved day?", isPresented: $confirmingClearAll, titleVisibility: .visible) {
                Button("Delete all days", role: .destructive) { model.clearAll() }
            }
            #endif
        }
        .environment(model.foodServices)
    }

    private func caption(for selection: DaySelection) -> String {
        switch selection.daysBack {
        case 0: "Today"
        case 1: "Yesterday"
        case let days: "\(days) days ago"
        }
    }
}
