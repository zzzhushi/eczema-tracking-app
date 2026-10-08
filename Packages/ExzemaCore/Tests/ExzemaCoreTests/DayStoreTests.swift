import Foundation
import Testing
import ExzemaCore

@Suite("Day store")
struct DayStoreTests {
    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DayStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private var storeURL: URL { directory.appendingPathComponent("store.sqlite") }

    private let sampleDay = Day(
        date: LocalDate(year: 2026, month: 10, day: 7),
        timeZoneIdentifier: "America/Los_Angeles"
    )

    @Test func savedDayReadsBackIdenticallyAfterReopeningTheStore() throws {
        do {
            let store = try DayStore(at: storeURL)
            try store.save(sampleDay)
        }

        let reopened = try DayStore(at: storeURL)

        #expect(try reopened.days() == [sampleDay])
    }

    @Test func savingTheSameDayTwiceKeepsOneRecord() throws {
        let store = try DayStore(at: storeURL)
        try store.save(sampleDay)
        try store.save(sampleDay)

        #expect(try store.days() == [sampleDay])
    }

    @Test func daysAreListedNewestFirst() throws {
        let store = try DayStore(at: storeURL)
        let earlier = Day(date: LocalDate(year: 2026, month: 10, day: 5), timeZoneIdentifier: "Asia/Tokyo")
        try store.save(earlier)
        try store.save(sampleDay)

        #expect(try store.days() == [sampleDay, earlier])
    }

    @Test func newStoreCarriesTheCurrentSchemaVersion() throws {
        let store = try DayStore(at: storeURL)

        #expect(try store.schemaVersion() == DayStore.currentSchemaVersion)
        #expect(DayStore.currentSchemaVersion == 4)
    }

    @Test func storeFromANewerSchemaIsRefusedAndLeftUntouched() throws {
        _ = try DayStore(at: storeURL)
        try DayStoreTestSupport.setSchemaVersion(DayStore.currentSchemaVersion + 1, at: storeURL)
        let before = try Data(contentsOf: storeURL)

        #expect(throws: DayStoreError.newerSchema(found: DayStore.currentSchemaVersion + 1)) {
            _ = try DayStore(at: storeURL)
        }
        #expect(try Data(contentsOf: storeURL) == before, "a refused store must not be modified")
    }

    @Test func storeFileIsExcludedFromBackup() throws {
        _ = try DayStore(at: storeURL)

        let values = try storeURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test(arguments: [1, 2, 3, 4])
    func fixtureStoreOpensAndReadsItsDay(version: Int) throws {
        let fixture = try #require(
            Bundle.module.url(forResource: "v\(version)", withExtension: "sqlite", subdirectory: "Stores"),
            "missing fixture store for schema v\(version)"
        )
        let copy = directory.appendingPathComponent("v\(version).sqlite")
        try FileManager.default.copyItem(at: fixture, to: copy)

        let store = try DayStore(at: copy)

        #expect(try store.days() == [DayStoreTestSupport.fixtureDay])
        #expect(try store.schemaVersion() == DayStore.currentSchemaVersion)
        #expect(try store.activeAreas().map(\.id) == ["face", "hands"], "migrating an older store adds the areas")
        if version < 3 {
            #expect(try store.checkIns(on: DayStoreTestSupport.fixtureDay.date).isEmpty, "an older day has no ratings")
        }
        if version >= 3 {
            let checkIn = try #require(try store.checkIns(on: DayStoreTestSupport.fixtureDay.date).first)
            #expect((checkIn.areaID, checkIn.feel, checkIn.look) == ("face", 4, 6))
            #expect(checkIn.updatedAt == DayStoreTestSupport.fixtureRatedAt)
            let capture = try #require(try store.locationCaptures().first)
            #expect((capture.latitudeTenths, capture.longitudeTenths) == (378, -1224))
            #expect(capture.placeName == (version >= 4 ? "San Francisco" : nil), "older captures have no place name until looked up")
        }
    }
}
