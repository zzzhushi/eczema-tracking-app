import Foundation
import Testing
import ExzemaCore

private final class FakePlaces: PlaceNaming, @unchecked Sendable {
    var names: [String?] = []
    private(set) var requested: [Coordinate] = []

    func placeName(for coordinate: Coordinate) async -> String? {
        requested.append(coordinate)
        return names.isEmpty ? nil : names.removeFirst()
    }
}

private final class FixedSource: LocationSource, @unchecked Sendable {
    var next: Coordinate?
    func currentLocation() async -> Coordinate? { next }
}

private final class Clock: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
}

@Suite("Location place names")
struct LocationPlaceTests {
    private let directory: URL
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let start = Date(timeIntervalSince1970: 1_791_000_000)
    private let raw = Coordinate(latitude: 37.7749, longitude: -122.4194)

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocationPlaceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func openStore() throws -> DayStore {
        try DayStore(at: directory.appendingPathComponent("store.sqlite"))
    }

    private func recorder(_ store: DayStore, places: FakePlaces, clock: Clock) -> LocationRecorder {
        let source = FixedSource()
        source.next = raw
        return LocationRecorder(store: store, source: source, now: { clock.now }, timeZone: { losAngeles }, places: places)
    }

    @Test func aNewCaptureIsNamedFromItsRoundedCoordinateNotTheRawOne() async throws {
        let store = try openStore()
        let places = FakePlaces()
        places.names = ["San Francisco"]

        _ = await recorder(store, places: places, clock: Clock(start)).captureIfDue()
        _ = await recorder(store, places: places, clock: Clock(start)).fillMissingPlaceNames()

        #expect(places.requested == [Coordinate(latitude: 37.8, longitude: -122.4)], "only the rounded coordinate may leave the phone")
        #expect(try store.locationCaptures().first?.placeName == "San Francisco")
    }

    @Test func aPlaceAlreadyNamedIsReusedWithoutAskingAgain() async throws {
        let store = try openStore()
        let places = FakePlaces()
        places.names = ["San Francisco"]
        let clock = Clock(start)
        let recorder = recorder(store, places: places, clock: clock)

        _ = await recorder.captureIfDue()
        _ = await recorder.fillMissingPlaceNames()
        clock.now = start.addingTimeInterval(2 * 3_600)
        _ = await recorder.captureIfDue()
        _ = await recorder.fillMissingPlaceNames()

        #expect(places.requested.count == 1, "the second capture is the same rounded place")
        #expect(try store.locationCaptures().map(\.placeName) == ["San Francisco", "San Francisco"])
    }

    @Test func aFailedLookupLeavesTheCaptureUnnamedAndTheNextPassTriesAgain() async throws {
        let store = try openStore()
        let places = FakePlaces()
        places.names = [nil, "San Francisco"]
        let recorder = recorder(store, places: places, clock: Clock(start))
        _ = await recorder.captureIfDue()

        let first = await recorder.fillMissingPlaceNames()
        #expect(first == 0)
        #expect(try store.locationCaptures().first?.placeName == nil, "a capture without a name is still a capture")

        let second = await recorder.fillMissingPlaceNames()
        #expect(second == 1)
        #expect(try store.locationCaptures().first?.placeName == "San Francisco")
    }

    @Test func oneLookupServesEveryUnnamedCaptureAtTheSameRoundedPlace() async throws {
        let store = try openStore()
        let places = FakePlaces()
        places.names = ["San Francisco"]
        try store.addLocationCapture(raw, at: start, in: losAngeles)
        try store.addLocationCapture(raw, at: start.addingTimeInterval(7_200), in: losAngeles)

        let named = await recorder(store, places: places, clock: Clock(start)).fillMissingPlaceNames()

        #expect(named == 2)
        #expect(places.requested.count == 1)
    }

    @Test func blankNamesAreNotStored() async throws {
        let store = try openStore()
        let places = FakePlaces()
        places.names = ["   "]
        try store.addLocationCapture(raw, at: start, in: losAngeles)

        _ = await recorder(store, places: places, clock: Clock(start)).fillMissingPlaceNames()

        #expect(try store.locationCaptures().first?.placeName == nil)
    }

    @Test func aDayListsItsDistinctPlacesInTheOrderTheyWereVisited() throws {
        let store = try openStore()
        let oakland = Coordinate(latitude: 37.8044, longitude: -122.2712)
        let tenAM = start
        for (coordinate, offset, name) in [(raw, 0.0, "San Francisco"), (oakland, 3_600.0, "Oakland"), (raw, 7_200.0, "San Francisco")] {
            try store.addLocationCapture(coordinate, at: tenAM.addingTimeInterval(offset), in: losAngeles)
            let id = try #require(try store.locationCaptures().last?.id)
            try store.setPlaceName(name, forCaptureID: id)
        }
        let date = Day(loggedAt: tenAM, in: losAngeles).date

        let places = try store.places(on: date)

        #expect(places.names == ["San Francisco", "Oakland"])
        #expect(places.captureCount == 3)
    }

    @Test func aDayWithCapturesButNoNamesReportsTheCapturesSoTheScreenCanSaySo() throws {
        let store = try openStore()
        try store.addLocationCapture(raw, at: start, in: losAngeles)
        let date = Day(loggedAt: start, in: losAngeles).date

        let places = try store.places(on: date)

        #expect(places.names.isEmpty)
        #expect(places.captureCount == 1)
    }

    @Test func aDayWithNoCapturesReportsNothing() throws {
        let store = try openStore()
        let places = try store.places(on: LocalDate(year: 2026, month: 10, day: 6))

        #expect(places.names.isEmpty && places.captureCount == 0, "no capture is unknown, not a place")
    }
}
