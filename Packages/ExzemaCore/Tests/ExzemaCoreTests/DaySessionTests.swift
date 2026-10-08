import Foundation
import Testing
@testable import ExzemaCore

/// Wiring only: the policy behind each event is owned by `DayHostModelTests`.
@MainActor
@Suite("Day session")
struct DaySessionTests {
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let lateEvening = Date(timeIntervalSince1970: 1_791_442_680) // 2026-10-07 23:58 in Los Angeles
    private let oct7 = LocalDate(year: 2026, month: 10, day: 7)
    private let oct8 = LocalDate(year: 2026, month: 10, day: 8)

    private final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func makeSession(_ clock: Clock) -> DaySession {
        DaySession(clock: { clock.now }, timeZone: { losAngeles })
    }

    @Test func theClockEventReachesTheHost() {
        let clock = Clock(lateEvening)
        let session = makeSession(clock)

        clock.now = lateEvening.addingTimeInterval(180)
        session.handle(.clockChanged)

        #expect(session.host.today.date == oct8)
    }

    @Test func theLifecycleEventsReachTheHost() {
        let clock = Clock(lateEvening)
        let session = makeSession(clock)
        session.handle(.enteredBackground)

        clock.now = lateEvening.addingTimeInterval(10 * 3600)
        session.handle(.becameActive)

        #expect(session.host.day.date == oct8, "returning after the date changed must open today")
    }

    @Test func foodDraftsCountAsUnsavedWorkForTheHost() {
        let clock = Clock(lateEvening)
        let session = makeSession(clock)
        session.foodDrafts.setText("rice", for: oct7)
        session.handle(.enteredBackground)

        clock.now = lateEvening.addingTimeInterval(10 * 3600)
        session.handle(.becameActive)

        #expect(session.host.day.date == oct7)
    }

    @Test func theFoodModelItBuildsSharesTheSessionsDrafts() throws {
        let clock = Clock(lateEvening)
        let session = makeSession(clock)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DaySessionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try DayStore(at: directory.appendingPathComponent("store.sqlite"))
        let matching = try FoodMatching.load(dataDirectory: shippedDataDirectory)
        let model = session.makeFoodLogModel(for: session.host.day, store: store, matcher: matching.matcher)

        model.updateDraft("rice")

        #expect(session.foodDrafts.text(for: oct7) == "rice")
    }
}
