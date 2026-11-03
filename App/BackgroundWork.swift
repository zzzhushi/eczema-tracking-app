import ExzemaCore
import UIKit

/// Asks iOS for time to finish a short job after the app leaves the foreground.
///
/// iOS grants a limited time. When it runs out the task ends and the job may be suspended, which is logged.
@MainActor
final class BackgroundWork {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    init(name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            Log.app.error("backgroundWork.expired")
            self?.end()
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
