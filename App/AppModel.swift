import ExzemaCore
import Foundation
import Observation

/// Opens the store and diagnostics at launch and exposes the saved days and the selected day to the screens.
@MainActor
@Observable
final class AppModel {
    private(set) var days: [Day] = []
    private(set) var navigation = DayNavigation(today: AppModel.currentDate())
    private(set) var areas: [Area] = []
    private(set) var checkIns: [String: CheckIn] = [:]
    private(set) var failure: String?

    var savedDates: Set<LocalDate> { Set(days.map(\.date)) }

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
        reload()
    }

    func select(_ date: LocalDate) {
        navigation.select(date)
        reloadCheckIns()
    }

    /// Re-read the phone's date; call when the app becomes active, since midnight may have passed.
    func refreshDate() {
        navigation.dateChanged(to: Self.currentDate())
        reloadCheckIns()
    }

    /// Give the selected day's area a rating, or clear it with nil.
    func setRating(_ kind: RatingKind, to value: Int?, area: Area) {
        guard let store else { return }
        let day = Day(date: navigation.selected, timeZoneIdentifier: TimeZone.current.identifier)
        do {
            try store.setRating(kind, to: value, area: area.id, on: day)
        } catch {
            Log.checkIn.error("checkin.saveFailed", private: ["error": String(describing: error)])
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
        days = read("days") { try $0.days() } ?? []
        areas = read("areas") { try $0.activeAreas() } ?? []
        reloadCheckIns()
    }

    private func reloadCheckIns() {
        let rows = read("checkIns") { try $0.checkIns(on: navigation.selected) } ?? []
        checkIns = Dictionary(uniqueKeysWithValues: rows.map { ($0.areaID, $0) })
    }

    /// Read from the store, logging a failure instead of silently showing an empty screen.
    private func read<Value>(_ name: StaticString, _ query: (DayStore) throws -> Value) -> Value? {
        guard let store else { return nil }
        do {
            return try query(store)
        } catch {
            Log.storage.error("store.readFailed", public: ["query": .text(name)], private: ["error": String(describing: error)])
            return nil
        }
    }

    private static func currentDate() -> LocalDate {
        Day(loggedAt: Date(), in: .current).date
    }
}
