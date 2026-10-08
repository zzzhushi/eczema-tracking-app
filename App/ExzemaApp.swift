import ExzemaCore
import SwiftUI

@main
struct ExzemaApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            DayHostView(model: model)
        }
    }
}
