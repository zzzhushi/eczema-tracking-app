import SwiftUI

/// Shows the first-launch statement once, then the day screen.
struct RootView: View {
    let model: AppModel
    @AppStorage("firstLaunchAcknowledged") private var acknowledged = false

    var body: some View {
        if acknowledged {
            DayScreen(model: model)
        } else {
            FirstLaunchView { acknowledged = true }
        }
    }
}
