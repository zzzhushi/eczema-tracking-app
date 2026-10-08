import ExzemaCore
import Foundation
import Observation

/// Opens the store and diagnostics at launch and exposes the saved days to the screen.
@MainActor
@Observable
final class AppModel {
    private(set) var days: [Day] = []
    private(set) var failure: String?
    private(set) var catalogFailure: String?
    /// Nil when the bundled catalog failed to load; nothing parses food without it.
    private(set) var foodMatching: FoodMatching?

    private let store: DayStore?
    private let diagnostics = DiagnosticsListener()

    init() {
        Log.app.notice("app.launched", public: ["build": .int(BuildInfo(stamp: BuildStamp.value).number ?? 0)])
        do {
            let directory = try AppPaths.applicationSupport().appendingPathComponent("Store", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            store = try DayStore(at: directory.appendingPathComponent("store.sqlite"))
        } catch {
            store = nil
            failure = "The store could not be opened."
            Log.storage.fault("store.unavailable", private: ["error": String(describing: error)])
        }
        loadCatalog()
        reload()
    }

    private func loadCatalog() {
        do {
            guard let directory = Bundle.main.resourceURL else { throw CocoaError(.fileNoSuchFile) }
            let matching = try FoodMatching.load(dataDirectory: directory)
            foodMatching = matching
            Log.foodLogging.notice("catalog.loaded", public: [
                "catalogVersion": .int(matching.catalog.manifest.catalogVersion),
                "foods": .int(matching.catalog.foods.count),
            ])
        } catch {
            catalogFailure = "The food catalog could not be loaded."
            Log.foodLogging.fault("catalog.unavailable", private: ["error": String(describing: error)])
        }
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

    #if DEBUG
    func clearToday() {
        guard let store else { return }
        try? store.delete(Day(loggedAt: Date(), in: .current).date)
        reload()
    }

    func clearAll() {
        guard let store else { return }
        try? store.deleteAll()
        reload()
    }
    #endif

    private func reload() {
        days = (try? store?.days()) ?? []
    }
}
