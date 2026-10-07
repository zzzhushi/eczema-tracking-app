import Foundation
import Testing
import ExzemaCore

@Suite("Day store deletion")
struct DayStoreDeletionTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("DayStoreDeletionTests-\(UUID().uuidString)", isDirectory: true)

    private let monday = Day(date: LocalDate(year: 2026, month: 10, day: 5), timeZoneIdentifier: "America/Los_Angeles")
    private let tuesday = Day(date: LocalDate(year: 2026, month: 10, day: 6), timeZoneIdentifier: "America/Los_Angeles")
    private let sink = RecordingLogSink()

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func openStore(logging: Bool = false) throws -> DayStore {
        let url = directory.appendingPathComponent("store.sqlite")
        return logging ? try DayStore(at: url, log: CategoryLogger(.storage, sink: sink)) : try DayStore(at: url)
    }

    @Test func deletingADayKeepsTheOthers() throws {
        let store = try openStore()
        try store.save(monday)
        try store.save(tuesday)

        try store.delete(monday.date)

        #expect(try store.days() == [tuesday])
    }

    @Test func deletingADayThatWasNeverSavedChangesNothing() throws {
        let store = try openStore()
        try store.save(monday)

        try store.delete(tuesday.date)

        #expect(try store.days() == [monday])
    }

    @Test func deletingAllDaysEmptiesTheStoreButKeepsItUsable() throws {
        let store = try openStore()
        try store.save(monday)
        try store.save(tuesday)

        try store.deleteAll()

        #expect(try store.days().isEmpty)
        #expect(try store.schemaVersion() == DayStore.currentSchemaVersion)
        try store.save(monday)
        #expect(try store.days() == [monday], "the store accepts new days after being cleared")
    }

    @Test func clearingLogsHowManyDaysWereRemovedWithoutNamingThem() throws {
        let store = try openStore(logging: true)
        try store.save(monday)
        try store.save(tuesday)

        try store.deleteAll()

        let cleared = try #require(sink.records.last)
        #expect(cleared.event == "days.cleared")
        #expect(cleared.publicFields == ["count": .int(2)])
        #expect(cleared.privateFields.isEmpty)
    }
}
