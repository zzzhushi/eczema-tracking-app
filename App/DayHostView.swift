import ExzemaCore
import SwiftUI

/// The home screen: a week strip over the shown day's check-in and food.
///
/// The date on screen changes only when the user taps a date or Today, or returns to the app after the date
/// changed with nothing unsaved. Clock and lifecycle changes reach the session through `DayEvent`s: the
/// calendar day and time zone changing refresh what "today" is and never move the screen.
struct DayHostView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSettings = false

    private struct LoadKey: Hashable {
        let date: LocalDate
        let dataVersion: Int
    }

    var body: some View {
        let host = model.session.host
        let day = host.day
        NavigationStack {
            VStack(spacing: 0) {
                WeekStripView(model: model)
                Divider()
                List {
                    if let failure = model.failure {
                        Text(failure).foregroundStyle(.red)
                    }
                    if let catalogFailure = model.catalogFailure {
                        Text(catalogFailure).foregroundStyle(.red)
                    }
                    if let loadFailure = model.loadFailure {
                        Text(loadFailure).foregroundStyle(.red)
                    }
                    if host.isAfterToday {
                        Text("Later than today here").foregroundStyle(.secondary)
                    }
                    CheckInSection(model: model)
                    FoodSectionView(day: day)
                        .id(model.dataVersion)
                    LocationSection(model: model)
                }
                .scrollDismissesKeyboard(.interactively)
                .task(id: LoadKey(date: host.shownDate, dataVersion: model.dataVersion)) {
                    model.loadCheckIns()
                    model.loadPlaces()
                }
            }
            .navigationTitle(day.date.longTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !host.isShowingToday {
                        Button("Today") { host.goToToday() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(model: model)
            }
        }
        .environment(model.foodServices)
        .onAppear { model.captureLocationIfDue() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: model.session.handle(.enteredBackground)
            case .active:
                model.session.handle(.becameActive)
                model.captureLocationIfDue()
            default: break
            }
        }
    }
}
