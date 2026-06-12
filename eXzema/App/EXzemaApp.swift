import SwiftUI
import SwiftData

@main
struct EXzemaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            Product.self,
            ExposureEntry.self,
            FlareEvent.self,
            EnvironmentEntry.self,
        ])
    }
}
