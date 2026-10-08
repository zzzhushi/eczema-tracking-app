import ExzemaCore
import SwiftUI
import UIKit

/// Opens on today and steps back through earlier days; the food section does all the food work.
///
/// The day on screen is refreshed when the calendar day or time zone changes and when the app returns to the
/// foreground, so a screen left open past midnight moves to the new day.
struct DayHostView: View {
    let model: AppModel
    @State private var host = DayHostModel()
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @State private var confirmingClearAll = false
    #endif

    var body: some View {
        let day = host.day
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
                        Button { host.goBack() } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Previous day")
                        Spacer()
                        VStack {
                            Text(day.date.isoString).font(.headline)
                            Text(caption).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { host.goForward() } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Next day")
                            .disabled(!host.canGoForward)
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
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in host.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in host.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in host.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { host.refresh() }
        }
    }

    private var caption: String {
        switch host.daysBack {
        case 0: "Today"
        case 1: "Yesterday"
        case let days: "\(days) days ago"
        }
    }
}
