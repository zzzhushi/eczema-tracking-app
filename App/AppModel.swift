import ExzemaCore
import Foundation
import Observation

/// Opens the store, catalog, and diagnostics at launch and hands the food section what it needs.
@MainActor
@Observable
final class AppModel {
    private(set) var failure: String?
    private(set) var catalogFailure: String?
    let foodServices: FoodServices
    /// Changes when debug actions clear data, so the food section reloads.
    private(set) var dataVersion = 0

    private let store: DayStore?
    private let diagnostics = DiagnosticsListener()

    init() {
        Log.app.notice("app.launched", public: ["build": .int(BuildInfo(stamp: BuildStamp.value).number ?? 0)])
        let openedStore: DayStore?
        do {
            let directory = try AppPaths.applicationSupport().appendingPathComponent("Store", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            openedStore = try DayStore(at: directory.appendingPathComponent("store.sqlite"))
        } catch {
            openedStore = nil
            failure = "The store could not be opened."
            Log.storage.fault("store.unavailable", private: ["error": String(describing: error)])
        }
        let matching = Self.loadCatalog()
        if matching == nil { catalogFailure = "The food catalog could not be loaded." }
        store = openedStore
        foodServices = FoodServices(store: openedStore, matching: matching)
    }

    /// Nil when the bundled catalog cannot be loaded; nothing parses food without it.
    private static func loadCatalog() -> FoodMatching? {
        do {
            guard let directory = Bundle.main.resourceURL else { throw CocoaError(.fileNoSuchFile) }
            let matching = try FoodMatching.load(dataDirectory: directory)
            Log.foodLogging.notice("catalog.loaded", public: [
                "catalogVersion": .int(matching.catalog.manifest.catalogVersion),
                "foods": .int(matching.catalog.foods.count),
            ])
            return matching
        } catch {
            Log.foodLogging.fault("catalog.unavailable", private: ["error": String(describing: error)])
            return nil
        }
    }

    #if DEBUG
    func clearToday() {
        guard let store else { return }
        try? store.delete(Day(loggedAt: Date(), in: .current).date)
        dataVersion += 1
    }

    func clearAll() {
        guard let store else { return }
        try? store.deleteAll()
        dataVersion += 1
    }
    #endif
}
