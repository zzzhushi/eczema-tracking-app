import Foundation
import Testing
import ExzemaCore

private final class FakeLocationSource: LocationSource, @unchecked Sendable {
    var next: Coordinate?
    private(set) var requests = 0

    func currentLocation() async -> Coordinate? {
        requests += 1
        return next
    }
}

private final class FakeClock: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
}

@Suite("Location capture")
struct LocationCaptureTests {
    private let directory: URL
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let start = Date(timeIntervalSince1970: 1_791_000_000)
    private let sanFrancisco = Coordinate(latitude: 37.7749, longitude: -122.4194)

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocationCaptureTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func openStore() throws -> DayStore {
        try DayStore(at: directory.appendingPathComponent("store.sqlite"))
    }

    private func recorder(
        _ store: DayStore, source: FakeLocationSource, clock: FakeClock
    ) -> LocationRecorder {
        LocationRecorder(store: store, source: source, now: { clock.now }, timeZone: { losAngeles })
    }

    @Test func coordinatesAreRoundedToTenthsOfADegree() throws {
        let store = try openStore()
        try store.addLocationCapture(sanFrancisco, at: start, in: losAngeles)

        let capture = try #require(try store.locationCaptures().first)
        #expect((capture.latitudeTenths, capture.longitudeTenths) == (378, -1224))
    }

    @Test func halfwayValuesRoundAwayFromZero() throws {
        let store = try openStore()
        try store.addLocationCapture(Coordinate(latitude: 37.75, longitude: -122.45), at: start, in: losAngeles)

        let capture = try #require(try store.locationCaptures().first)
        #expect((capture.latitudeTenths, capture.longitudeTenths) == (378, -1225))
    }

    @Test func captureRecordsTheLocalDateAndTimeZoneNotTheUTCDate() throws {
        let store = try openStore()
        let utcOctober7Morning = Date(timeIntervalSince1970: 1_791_338_400)
        try store.addLocationCapture(sanFrancisco, at: utcOctober7Morning, in: losAngeles)

        let capture = try #require(try store.locationCaptures().first)
        #expect(capture.localDate == LocalDate(year: 2026, month: 10, day: 6), "02:00 UTC is still 6 October in Los Angeles")
        #expect(capture.timeZoneIdentifier == "America/Los_Angeles")
    }

    @Test(arguments: [
        Coordinate(latitude: .nan, longitude: 0),
        Coordinate(latitude: 0, longitude: .infinity),
        Coordinate(latitude: 90.5, longitude: 0),
        Coordinate(latitude: 0, longitude: -180.5),
    ])
    func impossibleCoordinatesAreNotStored(coordinate: Coordinate) throws {
        let store = try openStore()
        try store.addLocationCapture(coordinate, at: start, in: losAngeles)

        #expect(try store.locationCaptures().isEmpty)
    }

    @Test func capturesSurviveReopeningTheStore() throws {
        do { try openStore().addLocationCapture(sanFrancisco, at: start, in: losAngeles) }

        #expect(try openStore().locationCaptures().count == 1)
    }

    @Test func firstActivationRecordsALocation() async throws {
        let store = try openStore()
        let source = FakeLocationSource()
        source.next = sanFrancisco

        let stored = await recorder(store, source: source, clock: FakeClock(start)).captureIfDue()

        #expect(stored)
        #expect(try store.locationCaptures().count == 1)
    }

    @Test func activationWithinAnHourOfTheLastCaptureWritesNothingAndSkipsTheRequest() async throws {
        let store = try openStore()
        let source = FakeLocationSource()
        source.next = sanFrancisco
        let clock = FakeClock(start)
        let recorder = recorder(store, source: source, clock: clock)
        _ = await recorder.captureIfDue()

        clock.now = start.addingTimeInterval(59 * 60)
        let stored = await recorder.captureIfDue()

        #expect(!stored)
        #expect(try store.locationCaptures().count == 1)
        #expect(source.requests == 1, "a capture that is not due must not ask the phone for a location")
    }

    @Test func activationExactlyAnHourAfterTheLastCaptureRecordsAgain() async throws {
        let store = try openStore()
        let source = FakeLocationSource()
        source.next = sanFrancisco
        let clock = FakeClock(start)
        let recorder = recorder(store, source: source, clock: clock)
        _ = await recorder.captureIfDue()

        clock.now = start.addingTimeInterval(60 * 60)
        let stored = await recorder.captureIfDue()

        #expect(stored, "a capture is suppressed only while the newest one is less than an hour old")
        #expect(try store.locationCaptures().count == 2)
    }

    @Test func activationMoreThanAnHourAfterTheLastCaptureRecordsAgain() async throws {
        let store = try openStore()
        let source = FakeLocationSource()
        source.next = sanFrancisco
        let clock = FakeClock(start)
        let recorder = recorder(store, source: source, clock: clock)
        _ = await recorder.captureIfDue()

        clock.now = start.addingTimeInterval(61 * 60)
        let stored = await recorder.captureIfDue()

        #expect(stored)
        #expect(try store.locationCaptures().count == 2)
    }

    @Test func clockMovedBackwardsDoesNotBlockCapturingUntilTimeCatchesUp() async throws {
        let store = try openStore()
        let source = FakeLocationSource()
        source.next = sanFrancisco
        let clock = FakeClock(start)
        let recorder = recorder(store, source: source, clock: clock)
        _ = await recorder.captureIfDue()

        clock.now = start.addingTimeInterval(-3 * 3_600)
        let stored = await recorder.captureIfDue()

        #expect(stored)
    }

    @Test func noLocationAvailableWritesNothingAndTheNextActivationTriesAgain() async throws {
        let store = try openStore()
        let source = FakeLocationSource()
        let clock = FakeClock(start)
        let recorder = recorder(store, source: source, clock: clock)

        let first = await recorder.captureIfDue()
        clock.now = start.addingTimeInterval(60)
        source.next = sanFrancisco
        let second = await recorder.captureIfDue()

        #expect(!first)
        #expect(second, "an unavailable location must not start the one-hour wait")
        #expect(try store.locationCaptures().count == 1)
    }

    @Test func capturingALocationNeverCreatesADay() async throws {
        let store = try openStore()
        let source = FakeLocationSource()
        source.next = sanFrancisco

        _ = await recorder(store, source: source, clock: FakeClock(start)).captureIfDue()

        #expect(try store.days().isEmpty)
    }

    @Test func deletingEveryDayKeepsLocationCaptures() async throws {
        let store = try openStore()
        try store.addLocationCapture(sanFrancisco, at: start, in: losAngeles)

        try store.deleteAll()

        #expect(try store.locationCaptures().count == 1)
    }
}
