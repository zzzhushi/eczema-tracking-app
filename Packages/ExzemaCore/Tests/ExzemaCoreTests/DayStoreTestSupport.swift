import Foundation
import GRDB
import Testing
import ExzemaCore

enum DayStoreTestSupport {
    static let fixtureDay = Day(
        date: LocalDate(year: 2026, month: 10, day: 7),
        timeZoneIdentifier: "America/Los_Angeles"
    )

    static let fixtureRatedAt = Date(timeIntervalSince1970: 1_791_000_000)

    static func setSchemaVersion(_ version: Int, at url: URL) throws {
        let queue = try DatabaseQueue(path: url.path)
        try queue.writeWithoutTransaction { try $0.execute(sql: "PRAGMA user_version = \(version)") }
        try queue.close()
    }
}

/// Write the fixture store for the current schema version into the test sources.
///
/// Runs only when `EXZEMA_WRITE_FIXTURES=1`, because a fixture is written once per schema
/// version and then committed unchanged.
@Test(.enabled(if: ProcessInfo.processInfo.environment["EXZEMA_WRITE_FIXTURES"] == "1"))
func writeFixtureStoreForCurrentSchema() throws {
    let stores = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Stores", isDirectory: true)
    let url = stores.appendingPathComponent("v\(DayStore.currentSchemaVersion).sqlite")
    try? FileManager.default.removeItem(at: url)

    do {
        let store = try DayStore(at: url)
        try store.save(DayStoreTestSupport.fixtureDay)
        try store.setRating(.feel, to: 4, area: "face", on: DayStoreTestSupport.fixtureDay, at: DayStoreTestSupport.fixtureRatedAt)
        try store.setRating(.look, to: 6, area: "face", on: DayStoreTestSupport.fixtureDay, at: DayStoreTestSupport.fixtureRatedAt)
        try store.addLocationCapture(
            Coordinate(latitude: 37.7749, longitude: -122.4194),
            at: DayStoreTestSupport.fixtureRatedAt,
            in: TimeZone(identifier: DayStoreTestSupport.fixtureDay.timeZoneIdentifier)!
        )
    }

    let queue = try DatabaseQueue(path: url.path)
    try queue.writeWithoutTransaction { try $0.execute(sql: "PRAGMA journal_mode = DELETE; VACUUM") }
    try queue.close()
}
