import Foundation
import Testing
import ExzemaCore

@Suite("Food log store")
struct FoodLogStoreTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FoodLogStoreTests-\(UUID().uuidString)", isDirectory: true)

    private let day = Day(date: LocalDate(year: 2026, month: 10, day: 7), timeZoneIdentifier: "America/Los_Angeles")
    private let otherDay = Day(date: LocalDate(year: 2026, month: 10, day: 6), timeZoneIdentifier: "America/Los_Angeles")

    private let oatmeal = ParsedItem(text: "oatmeal", resolution: .matched(foodID: "oatmeal"))
    private let rice = ParsedItem(text: "rice", resolution: .matched(foodID: "white-rice"))
    private let dragonfruit = ParsedItem(text: "dragonfruit", resolution: .unrecognized)

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private var storeURL: URL { directory.appendingPathComponent("store.sqlite") }

    private func openStore() throws -> DayStore { try DayStore(at: storeURL) }

    @Test func savedLineReadsBackWithItsTextTimeZoneAndItemsInOrder() throws {
        let store = try openStore()
        let id = try store.addFoodLine(text: "oatmeal, dragonfruit, rice", items: [oatmeal, dragonfruit, rice], on: day)

        let lines = try store.foodLines(on: day.date)

        #expect(lines.map(\.id) == [id])
        #expect(lines.first?.text == "oatmeal, dragonfruit, rice")
        #expect(lines.first?.timeZoneIdentifier == "America/Los_Angeles")
        #expect(lines.first?.items.map(\.item) == [oatmeal, dragonfruit, rice])
    }

    @Test func savedLinesSurviveReopeningTheStore() throws {
        do {
            _ = try openStore().addFoodLine(text: "oatmeal", items: [oatmeal], on: day)
        }

        #expect(try openStore().foodLines(on: day.date).map(\.text) == ["oatmeal"])
    }

    @Test func linesOnOneDayComeBackInTheOrderTheyWereSaved() throws {
        let store = try openStore()
        _ = try store.addFoodLine(text: "oatmeal", items: [oatmeal], on: day)
        _ = try store.addFoodLine(text: "rice", items: [rice], on: day)

        #expect(try store.foodLines(on: day.date).map(\.text) == ["oatmeal", "rice"])
    }

    @Test func linesBelongToTheirOwnDay() throws {
        let store = try openStore()
        _ = try store.addFoodLine(text: "oatmeal", items: [oatmeal], on: day)

        #expect(try store.foodLines(on: otherDay.date).isEmpty)
    }

    @Test func readingADayWithNoLinesCreatesNoDayRecord() throws {
        let store = try openStore()

        #expect(try store.foodLines(on: day.date).isEmpty)
        #expect(try store.isLogged(day.date) == false)
        #expect(try store.days().isEmpty, "browsing a day must not store it")
    }

    @Test func firstLineStoresTheDayAndLaterLinesKeepItsTimeZone() throws {
        let store = try openStore()
        _ = try store.addFoodLine(text: "oatmeal", items: [oatmeal], on: day)
        let traveling = Day(date: day.date, timeZoneIdentifier: "Asia/Tokyo")
        _ = try store.addFoodLine(text: "rice", items: [rice], on: traveling)

        #expect(try store.days() == [day])
        #expect(try store.foodLines(on: day.date).map(\.timeZoneIdentifier) == ["America/Los_Angeles", "Asia/Tokyo"])
    }

    @Test func dayWithAnItemIsLoggedAndOneWithoutIsNot() throws {
        let store = try openStore()
        _ = try store.addFoodLine(text: "oatmeal", items: [oatmeal], on: day)

        #expect(try store.isLogged(day.date))
        #expect(try store.isLogged(otherDay.date) == false)
    }

    @Test func lineWithNoItemsIsRefusedAndStoresNothing() throws {
        let store = try openStore()

        #expect(throws: DayStoreError.noItems) { _ = try store.addFoodLine(text: "and the", items: [], on: day) }
        #expect(try store.days().isEmpty)
    }

    @Test func replacingALineChangesItsTextAndItemsAndKeepsItsPlace() throws {
        let store = try openStore()
        let first = try store.addFoodLine(text: "oatmeal", items: [oatmeal], on: day)
        _ = try store.addFoodLine(text: "rice", items: [rice], on: day)

        try store.replaceFoodLine(first, text: "oatmeal, dragonfruit", items: [oatmeal, dragonfruit])

        let lines = try store.foodLines(on: day.date)
        #expect(lines.map(\.text) == ["oatmeal, dragonfruit", "rice"])
        #expect(lines.first?.items.map(\.item) == [oatmeal, dragonfruit])
    }

    @Test func replacingALineWithNoItemsIsRefusedAndKeepsTheLine() throws {
        let store = try openStore()
        let id = try store.addFoodLine(text: "oatmeal", items: [oatmeal], on: day)

        #expect(throws: DayStoreError.noItems) { try store.replaceFoodLine(id, text: "and", items: []) }
        #expect(try store.foodLines(on: day.date).map(\.text) == ["oatmeal"])
    }

    @Test func replacingALineThatDoesNotExistIsAnError() throws {
        let store = try openStore()

        #expect(throws: DayStoreError.unknownFoodLine) {
            try store.replaceFoodLine(FoodLineID(rawValue: 99), text: "oatmeal", items: [oatmeal])
        }
    }

    @Test func deletingALineKeepsTheOthersAndUnlogsAnEmptiedDay() throws {
        let store = try openStore()
        let first = try store.addFoodLine(text: "oatmeal", items: [oatmeal], on: day)
        let second = try store.addFoodLine(text: "rice", items: [rice], on: day)

        try store.deleteFoodLine(first)
        #expect(try store.foodLines(on: day.date).map(\.id) == [second])

        try store.deleteFoodLine(second)
        #expect(try store.isLogged(day.date) == false)
    }

    @Test func deletingOneItemKeepsTheRestOfItsLine() throws {
        let store = try openStore()
        _ = try store.addFoodLine(text: "oatmeal, dragonfruit", items: [oatmeal, dragonfruit], on: day)
        let noise = try #require(store.foodLines(on: day.date).first?.items.last)

        try store.deleteFoodItem(noise.id)

        #expect(try store.foodLines(on: day.date).first?.items.map(\.item) == [oatmeal])
    }

    @Test func deletingTheLastItemOfALineRemovesTheLine() throws {
        let store = try openStore()
        _ = try store.addFoodLine(text: "oatmeal", items: [oatmeal], on: day)
        let only = try #require(store.foodLines(on: day.date).first?.items.first)

        try store.deleteFoodItem(only.id)

        #expect(try store.foodLines(on: day.date).isEmpty)
        #expect(try store.isLogged(day.date) == false)
    }

    @Test func deletingAnItemThatDoesNotExistIsAnError() throws {
        #expect(throws: DayStoreError.unknownFoodItem) { try openStore().deleteFoodItem(FoodItemID(rawValue: 99)) }
    }

    @Test func deletingADayRemovesItsFoodButNotOtherDays() throws {
        let store = try openStore()
        _ = try store.addFoodLine(text: "oatmeal", items: [oatmeal], on: day)
        _ = try store.addFoodLine(text: "rice", items: [rice], on: otherDay)

        try store.delete(day.date)

        #expect(try store.foodLines(on: day.date).isEmpty)
        #expect(try store.foodLines(on: otherDay.date).map(\.text) == ["rice"])
    }

    @Test func clearingAllDaysRemovesAllFood() throws {
        let store = try openStore()
        _ = try store.addFoodLine(text: "oatmeal", items: [oatmeal], on: day)

        try store.deleteAll()

        #expect(try store.foodLines(on: day.date).isEmpty)
    }
}

@Suite("Schema v2 migration")
struct SchemaV2MigrationTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SchemaV2MigrationTests-\(UUID().uuidString)", isDirectory: true)

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func copyOfFixture(version: Int) throws -> URL {
        let fixture = try #require(
            Bundle.module.url(forResource: "v\(version)", withExtension: "sqlite", subdirectory: "Stores"),
            "missing fixture store for schema v\(version)"
        )
        let copy = directory.appendingPathComponent("v\(version).sqlite")
        try FileManager.default.copyItem(at: fixture, to: copy)
        return copy
    }

    @Test func aV1StoreMigratesToV2KeepingItsDaysAndTakingFood() throws {
        let store = try DayStore(at: copyOfFixture(version: 1))
        let item = ParsedItem(text: "rice", resolution: .matched(foodID: "white-rice"))

        #expect(try store.schemaVersion() == 2)
        #expect(try store.days() == [DayStoreTestSupport.fixtureDay])
        _ = try store.addFoodLine(text: "rice", items: [item], on: DayStoreTestSupport.fixtureDay)
        #expect(try store.foodLines(on: DayStoreTestSupport.fixtureDay.date).map(\.text) == ["rice"])
    }

    @Test func aV2FixtureKeepsItsDayAndFoodLine() throws {
        let store = try DayStore(at: copyOfFixture(version: 2))
        let lines = try store.foodLines(on: DayStoreTestSupport.fixtureDay.date)

        #expect(try store.days() == [DayStoreTestSupport.fixtureDay])
        #expect(lines.map(\.text) == ["oatmeal and dragonfruit"])
        #expect(lines.first?.items.map(\.item) == [
            ParsedItem(text: "oatmeal", resolution: .matched(foodID: "oatmeal")),
            ParsedItem(text: "dragonfruit", resolution: .unrecognized),
        ])
    }
}
