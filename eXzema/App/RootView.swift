import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            ProductsView()
                .tabItem { Label("Products", systemImage: "drop") }
            FlaresView()
                .tabItem { Label("Flares", systemImage: "flame") }
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar") }
            CheckProductView()
                .tabItem { Label("Check", systemImage: "magnifyingglass") }
        }
    }
}
