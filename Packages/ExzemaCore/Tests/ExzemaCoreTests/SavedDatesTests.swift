import Foundation
import Testing
import ExzemaCore

@Suite("Saved dates")
struct SavedDatesTests {
    private let monday = Day(date: LocalDate(year: 2026, month: 10, day: 5), timeZoneIdentifier: "America/Los_Angeles")
    private let tuesday = Day(date: LocalDate(year: 2026, month: 10, day: 6), timeZoneIdentifier: "America/Los_Angeles")

    private func openStore() throws -> DayStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SavedDatesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try DayStore(at: directory.appendingPathComponent("store.sqlite"))
    }

    @Test func emitsTheCurrentDatesThenEveryChangeFromAnyFeature() async throws {
        let store = try openStore()
        var values = store.savedDates().makeAsyncIterator()

        #expect(try await values.next() == [])

        try store.setRating(.feel, to: 3, area: "face", on: monday)
        #expect(try await values.next() == [monday.date], "a rating creates its day")

        try store.save(tuesday)
        #expect(try await values.next() == [monday.date, tuesday.date])

        try store.delete(monday.date)
        #expect(try await values.next() == [tuesday.date])
    }
}
