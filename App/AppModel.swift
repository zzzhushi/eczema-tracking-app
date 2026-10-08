import ExzemaCore
import Foundation
import Observation
import UIKit

/// Opens the store, catalog, and diagnostics at launch and hands the food section what it needs.
@MainActor
@Observable
final class AppModel {
    private(set) var failure: String?
    private(set) var catalogFailure: String?
    let foodServices: FoodServices
    let session: DaySession
    let location = LocationService()
    /// Dates that have a day row, kept current by observing the store.
    private(set) var savedDates: Set<LocalDate> = []
    private(set) var areas: [Area] = []
    private(set) var checkIns: [String: CheckIn] = [:]
    private(set) var places = DayPlaces(names: [], captureCount: 0)
    private var checkInsFailed = false
    private var placesFailed = false

    /// Set while the shown day's ratings or places could not be read; they then show as unknown, never as another
    /// day's values.
    var loadFailure: String? {
        checkInsFailed || placesFailed ? "Part of this day could not be loaded." : nil
    }
    /// Changes when debug actions clear data, so the food section reloads.
    private(set) var dataVersion = 0

    private let store: DayStore?
    private let locationRecorder: LocationRecorder?
    private var isCapturingLocation = false
    private let diagnostics = DiagnosticsListener()
    /// Kept so the session keeps hearing the system's clock notifications for the app's lifetime.
    private let dayEvents: DayEventObserver
    /// What the app takes as now: the real clock, or the debug clock that moves it in debug builds.
    private let clock: @Sendable () -> Date
    #if DEBUG
    private let debugClock: DebugClock
    #endif

    init() {
        if let directory = try? AppPaths.applicationSupport().appendingPathComponent("Logs", isDirectory: true) {
            try? LogFiles.enable(directory: directory)
        }
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
        #if DEBUG
        let debugClock = DebugClock()
        self.debugClock = debugClock
        let clock: @Sendable () -> Date = { debugClock.now }
        let session = DaySession(clock: clock)
        #else
        let clock: @Sendable () -> Date = { Date() }
        let session = DaySession()
        #endif
        self.session = session
        self.clock = clock
        let source = location
        locationRecorder = openedStore.map { LocationRecorder(store: $0, source: source, now: clock, places: CityNamer()) }
        foodServices = FoodServices(store: openedStore, matching: matching, session: session)
        dayEvents = DayEventObserver(
            session: session,
            clockNotifications: DayEventObserver.foundationClockNotifications + [UIApplication.significantTimeChangeNotification]
        )
        location.onAuthorized = { [weak self] in self?.captureLocationIfDue() }
        loadAreas()
        observeSavedDates()
    }

    /// Record the rounded location unless one was taken within the last hour; does nothing without permission.
    ///
    /// Overlapping calls are dropped so two triggers at launch cannot each store a capture.
    func captureLocationIfDue() {
        guard location.isAuthorized, let locationRecorder, !isCapturingLocation else { return }
        isCapturingLocation = true
        Task {
            await locationRecorder.captureIfDue()
            await locationRecorder.fillMissingPlaceNames()
            isCapturingLocation = false
            loadPlaces()
        }
    }

    /// Load the shown day's check-ins; call when the shown date or the stored data changes.
    func loadCheckIns() {
        checkIns = [:]
        checkInsFailed = false
        guard let store else { return }
        do {
            let rows = try store.checkIns(on: session.host.shownDate)
            checkIns = Dictionary(uniqueKeysWithValues: rows.map { ($0.areaID, $0) })
        } catch {
            checkInsFailed = true
            Log.storage.error("store.readFailed", public: ["query": "checkIns"], private: ["error": String(describing: error)])
        }
    }

    /// Load the places captured on the shown date.
    func loadPlaces() {
        places = DayPlaces(names: [], captureCount: 0)
        placesFailed = false
        guard let store else { return }
        do {
            places = try store.places(on: session.host.shownDate)
        } catch {
            placesFailed = true
            Log.storage.error("store.readFailed", public: ["query": "places"], private: ["error": String(describing: error)])
        }
    }

    /// Give the shown day's area a rating, or clear it with nil.
    func setRating(_ kind: RatingKind, to value: Int?, area: Area) {
        guard let store else { return }
        do {
            try store.setRating(kind, to: value, area: area.id, on: session.host.day, at: clock())
        } catch {
            Log.checkIn.error("checkin.saveFailed", private: ["error": String(describing: error)])
        }
        loadCheckIns()
    }

    private func loadAreas() {
        guard let store else { return }
        do {
            areas = try store.activeAreas()
        } catch {
            Log.storage.error("store.readFailed", public: ["query": "areas"], private: ["error": String(describing: error)])
        }
    }

    private func observeSavedDates() {
        guard let store else { return }
        Task { [weak self] in
            do {
                for try await dates in store.savedDates() { self?.savedDates = dates }
            } catch {
                Log.storage.error("store.observeFailed", private: ["error": String(describing: error)])
            }
        }
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
        try? store.delete(session.host.today.date)
        dataVersion += 1
        loadCheckIns()
    }

    /// Moves the app's clock to just after the next midnight and refreshes, as the system's day-changed
    /// notification does.
    func simulateMidnight() {
        debugClock.offset = nextMidnight().addingTimeInterval(60).timeIntervalSinceNow
        session.handle(.clockChanged)
    }

    /// Leaves the foreground, moves the clock to 8 a.m. the next day, and returns, as opening the app the
    /// next morning does.
    func simulateNextMorning() {
        session.handle(.enteredBackground)
        debugClock.offset = nextMidnight().addingTimeInterval(8 * 3600).timeIntervalSinceNow
        session.handle(.becameActive)
        captureLocationIfDue()
    }

    func resetClock() {
        debugClock.offset = 0
        session.handle(.clockChanged)
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
        loadCheckIns()
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
