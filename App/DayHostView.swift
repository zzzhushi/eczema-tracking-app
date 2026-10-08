import ExzemaCore
import SwiftUI
import UIKit

/// Shows one date at a time and steps through them; the food section does all the food work.
///
/// The date on screen changes only when the user steps, taps Today, or returns to the app after the date
/// changed with nothing unsaved. The calendar day and time zone changing refresh what "today" is, which
/// ages the caption and limits the forward arrow, and never move the screen.
struct DayHostView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @State private var confirmingClearAll = false
    #endif

    var body: some View {
        let host = model.host
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
                            Text(caption(host)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { host.goForward() } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Next day")
                            .disabled(!host.canGoForward)
                    }
                    .buttonStyle(.borderless)
                    if !host.isShowingToday {
                        Button("Back to today") { host.goToToday() }
                            .buttonStyle(.borderless)
                    }
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
                    Button("Simulate midnight") { model.simulateMidnight() }
                    Button("Simulate next morning") { model.simulateNextMorning() }
                    Button("Reset clock") { model.resetClock() }
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
            switch phase {
            case .background:
                host.wentToBackground()
            case .active:
                host.becameActive()
            default:
                break
            }
        }
    }

    private func caption(_ host: DayHostModel) -> String {
        if host.isAfterToday { return "Later than today here" }
        switch host.daysBack {
        case 0: return "Today"
        case 1: return "Yesterday"
        case let days: return "\(days) days ago"
        }
    }
}
