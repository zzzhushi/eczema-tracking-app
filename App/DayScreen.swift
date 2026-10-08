import ExzemaCore
import SwiftUI

/// The home screen: the week strip over the selected day's sections.
struct DayScreen: View {
    let model: AppModel
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WeekStripView(model: model)
                Divider()
                DayDetailView(model: model)
            }
            .navigationTitle(model.navigation.selected.longTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(model: model)
            }
        }
    }
}
