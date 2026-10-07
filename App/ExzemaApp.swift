import ExzemaCore
import SwiftUI

@main
struct ExzemaApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            DayListView(model: model)
        }
    }
}
