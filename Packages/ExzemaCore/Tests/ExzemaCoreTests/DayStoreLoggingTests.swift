import Foundation
import Testing
import ExzemaCore

@Suite("Day store logging and backup exclusion")
struct DayStoreLoggingTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("DayStoreLoggingTests-\(UUID().uuidString)", isDirectory: true)
    private let sink = RecordingLogSink()

    private var storeURL: URL { directory.appendingPathComponent("store.sqlite") }

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @Test func openingTheStoreLogsItsSchemaVersion() throws {
        _ = try DayStore(at: storeURL, log: CategoryLogger(.storage, sink: sink))

        #expect(sink.records == [
            LogRecord(
                category: .storage, level: .notice, event: "store.opened",
                publicFields: ["schemaVersion": .int(DayStore.currentSchemaVersion)], privateFields: [:]
            ),
        ])
    }

    @Test func refusingANewerStoreLogsAFaultWithBothVersions() throws {
        _ = try DayStore(at: storeURL)
        let newer = DayStore.currentSchemaVersion + 1
        try DayStoreTestSupport.setSchemaVersion(newer, at: storeURL)

        _ = try? DayStore(at: storeURL, log: CategoryLogger(.storage, sink: sink))

        #expect(sink.records == [
            LogRecord(
                category: .storage, level: .fault, event: "store.refused",
                publicFields: ["found": .int(newer), "supported": .int(DayStore.currentSchemaVersion)], privateFields: [:]
            ),
        ])
    }

    @Test func savingADayLogsItsDateAsPrivateAndWhetherItWasNew() throws {
        let store = try DayStore(at: storeURL, log: CategoryLogger(.storage, sink: sink))
        let day = Day(date: LocalDate(year: 2026, month: 10, day: 7), timeZoneIdentifier: "America/Los_Angeles")

        try store.save(day)
        try store.save(day)

        let saves = sink.records.filter { $0.event == "day.saved" }
        #expect(saves.map(\.publicFields) == [["inserted": .bool(true)], ["inserted": .bool(false)]])
        #expect(saves.map(\.privateFields) == [["date": "2026-10-07"], ["date": "2026-10-07"]], "the date is health-adjacent and must stay private")
        #expect(saves.allSatisfy { $0.level == .notice })
    }

    @Test func storeDirectoryIsExcludedSoSidecarFilesAreNeverBackedUp() throws {
        _ = try DayStore(at: storeURL)

        let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true, "files the database creates beside the store inherit the directory's exclusion")
    }
}
