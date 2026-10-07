import ExzemaCore
import Foundation
import Observation

/// Opens the store and diagnostics at launch and exposes the saved days to the screen.
@MainActor
@Observable
final class AppModel {
    private(set) var days: [Day] = []
    private(set) var failure: String?

    private let store: DayStore?
    private let diagnostics = DiagnosticsSubscriber()

    init() {
        Log.app.notice("app.launched")
        do {
            let directory = try AppPaths.applicationSupport().appendingPathComponent("Store", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            store = try DayStore(at: directory.appendingPathComponent("store.sqlite"))
        } catch {
            store = nil
            failure = "The store could not be opened."
            Log.storage.fault("store.unavailable", private: ["error": String(describing: error)])
        }
        reload()
    }

    func saveToday() {
        guard let store else { return }
        let day = Day(loggedAt: Date(), in: .current)
        do {
            try store.save(day)
        } catch {
            Log.storage.error("day.saveFailed", private: ["error": String(describing: error)])
        }
        reload()
    }

    private func reload() {
        days = (try? store?.days()) ?? []
    }
}
