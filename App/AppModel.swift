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
    let host: DayHostModel
    /// Changes when debug actions clear data, so the food section reloads.
    private(set) var dataVersion = 0

    private let store: DayStore?
    private let diagnostics = DiagnosticsListener()
    #if DEBUG
    private let debugClock: DebugClock
    #endif

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
        let foodDrafts = FoodDrafts()
        foodServices = FoodServices(store: openedStore, matching: matching, drafts: foodDrafts)
        // Each feature that keeps unsaved work adds its dates here; the host knows only the dates.
        let unsavedWork = { foodDrafts.datesWithUnsavedWork }
        #if DEBUG
        let debugClock = DebugClock()
        self.debugClock = debugClock
        host = DayHostModel(clock: { debugClock.now }, unsavedWork: unsavedWork)
        #else
        host = DayHostModel(unsavedWork: unsavedWork)
        #endif
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
        try? store.delete(host.today.date)
        dataVersion += 1
    }

    /// Moves the app's clock to just after the next midnight and refreshes, as the system's day-changed
    /// notification does.
    func simulateMidnight() {
        debugClock.offset = nextMidnight().addingTimeInterval(60).timeIntervalSinceNow
        host.refresh()
    }

    /// Leaves the foreground, moves the clock to 8 a.m. the next day, and returns, as opening the app the
    /// next morning does.
    func simulateNextMorning() {
        host.wentToBackground()
        debugClock.offset = nextMidnight().addingTimeInterval(8 * 3600).timeIntervalSinceNow
        host.becameActive()
    }

    func resetClock() {
        debugClock.offset = 0
        host.refresh()
    }

    private func nextMidnight() -> Date {
        Calendar.autoupdatingCurrent.nextDate(
            after: debugClock.now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime
        )!
    }

    func clearAll() {
        guard let store else { return }
        try? store.deleteAll()
        dataVersion += 1
    }
    #endif
}

#if DEBUG
/// Shifts what the app takes as now, so day boundaries can be walked through without waiting for midnight.
final class DebugClock: @unchecked Sendable {
    var offset: TimeInterval = 0
    var now: Date { Date().addingTimeInterval(offset) }
}
#endif
