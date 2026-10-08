import Foundation
import Testing
import ExzemaCore

@Suite("Check-in store")
struct CheckInStoreTests {
    private let directory: URL
    private let tuesday = Day(date: LocalDate(year: 2026, month: 10, day: 6), timeZoneIdentifier: "America/Los_Angeles")
    private let morning = Date(timeIntervalSince1970: 1_791_000_000)

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CheckInStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private var storeURL: URL { directory.appendingPathComponent("store.sqlite") }

    private func openStore() throws -> DayStore {
        try DayStore(at: storeURL)
    }

    @Test func newStoreOffersFaceThenHands() throws {
        let areas = try openStore().activeAreas()

        #expect(areas.map(\.id) == ["face", "hands"])
        #expect(areas.map(\.name) == ["Face", "Hands"])
    }

    @Test func dayWithoutRatingsHasNoCheckIns() throws {
        let store = try openStore()

        #expect(try store.checkIns(on: tuesday.date).isEmpty, "an unrated day is unknown, not a day of zeros")
    }

    @Test func readingADayNeverCreatesIt() throws {
        let store = try openStore()
        _ = try store.checkIns(on: tuesday.date)

        #expect(try store.days().isEmpty)
    }

    @Test func firstRatingCreatesTheDayWithItsTimeZone() throws {
        let store = try openStore()
        try store.setRating(.feel, to: 4, area: "face", on: tuesday, at: morning)

        #expect(try store.days() == [tuesday])
    }

    @Test func ratingOneFieldLeavesTheOtherUnknown() throws {
        let store = try openStore()
        try store.setRating(.feel, to: 4, area: "face", on: tuesday, at: morning)

        let checkIn = try #require(try store.checkIns(on: tuesday.date).first)
        #expect(checkIn.feel == 4)
        #expect(checkIn.look == nil, "an unrated look stays unknown, never 0")
    }

    @Test func otherAreasStayUnknown() throws {
        let store = try openStore()
        try store.setRating(.look, to: 2, area: "face", on: tuesday, at: morning)

        #expect(try store.checkIns(on: tuesday.date).map(\.areaID) == ["face"])
    }

    @Test func zeroIsARealRatingDistinctFromUnknown() throws {
        let store = try openStore()
        try store.setRating(.feel, to: 0, area: "hands", on: tuesday, at: morning)

        #expect(try store.checkIns(on: tuesday.date).first?.feel == 0)
    }

    @Test func latestValueIsTheDaysValueAndRecordsWhenItChanged() throws {
        let store = try openStore()
        try store.setRating(.feel, to: 4, area: "face", on: tuesday, at: morning)
        let later = morning.addingTimeInterval(3_600)
        try store.setRating(.feel, to: 6, area: "face", on: tuesday, at: later)

        let checkIn = try #require(try store.checkIns(on: tuesday.date).first)
        #expect(checkIn.feel == 6)
        #expect(checkIn.updatedAt == later)
    }

    @Test func ratingsSurviveReopeningTheStore() throws {
        do {
            let store = try openStore()
            try store.setRating(.feel, to: 4, area: "face", on: tuesday, at: morning)
            try store.setRating(.look, to: 7, area: "face", on: tuesday, at: morning)
        }

        let checkIn = try #require(try openStore().checkIns(on: tuesday.date).first)
        #expect(checkIn.feel == 4)
        #expect(checkIn.look == 7)
    }

    @Test func clearingARatingReturnsItToUnknown() throws {
        let store = try openStore()
        try store.setRating(.feel, to: 4, area: "face", on: tuesday, at: morning)
        try store.setRating(.feel, to: nil, area: "face", on: tuesday, at: morning.addingTimeInterval(60))

        #expect(try store.checkIns(on: tuesday.date).first?.feel == nil)
    }

    @Test func clearingARatingThatWasNeverGivenWritesNothing() throws {
        let store = try openStore()
        try store.setRating(.feel, to: nil, area: "face", on: tuesday, at: morning)

        #expect(try store.days().isEmpty)
        #expect(try store.checkIns(on: tuesday.date).isEmpty)
    }

    @Test(arguments: [-1, 11])
    func ratingOutsideZeroToTenIsRejectedAndWritesNothing(value: Int) throws {
        let store = try openStore()

        #expect(throws: CheckInError.ratingOutOfRange(value)) {
            try store.setRating(.feel, to: value, area: "face", on: tuesday, at: morning)
        }
        #expect(try store.days().isEmpty)
    }

    @Test func unknownAreaIsRejectedAndWritesNothing() throws {
        let store = try openStore()

        #expect(throws: (any Error).self) {
            try store.setRating(.feel, to: 3, area: "elbows", on: tuesday, at: morning)
        }
        #expect(try store.days().isEmpty)
    }

    @Test func dayKeepsTheTimeZoneItWasFirstLoggedIn() throws {
        let store = try openStore()
        try store.setRating(.feel, to: 4, area: "face", on: tuesday, at: morning)
        let abroad = Day(date: tuesday.date, timeZoneIdentifier: "Asia/Tokyo")
        try store.setRating(.look, to: 5, area: "face", on: abroad, at: morning.addingTimeInterval(60))

        #expect(try store.days() == [tuesday])
    }

    @Test func deletingADayDeletesItsCheckIns() throws {
        let store = try openStore()
        try store.setRating(.feel, to: 4, area: "face", on: tuesday, at: morning)

        try store.delete(tuesday.date)

        #expect(try store.checkIns(on: tuesday.date).isEmpty)
    }

    @Test func clearingEveryDayDeletesEveryCheckIn() throws {
        let store = try openStore()
        try store.setRating(.feel, to: 4, area: "face", on: tuesday, at: morning)

        try store.deleteAll()

        #expect(try store.checkIns(on: tuesday.date).isEmpty)
    }
}
