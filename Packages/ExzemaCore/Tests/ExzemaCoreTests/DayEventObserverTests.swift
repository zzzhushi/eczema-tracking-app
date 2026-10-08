import Foundation
import Testing
@testable import ExzemaCore

@MainActor
@Suite("Day event observer")
struct DayEventObserverTests {
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let lateEvening = Date(timeIntervalSince1970: 1_791_442_680) // 2026-10-07 23:58 in Los Angeles
    private let oct8 = LocalDate(year: 2026, month: 10, day: 8)
    private let extraName = Notification.Name("test.significantTimeChange")

    private final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func makeSession(_ clock: Clock) -> DaySession {
        DaySession(clock: { clock.now }, timeZone: { losAngeles })
    }

    @Test(arguments: [Notification.Name.NSCalendarDayChanged, .NSSystemTimeZoneDidChange, Notification.Name("test.significantTimeChange")])
    func eachClockNotificationRefreshesWhatTodayIs(name: Notification.Name) {
        let clock = Clock(lateEvening)
        let session = makeSession(clock)
        let center = NotificationCenter()
        let observer = DayEventObserver(
            session: session, center: center,
            clockNotifications: DayEventObserver.foundationClockNotifications + [extraName]
        )

        clock.now = lateEvening.addingTimeInterval(180)
        center.post(name: name, object: nil)

        #expect(session.host.today.date == oct8)
        withExtendedLifetime(observer) {}
    }

    @Test func aNotificationItDoesNotWatchChangesNothing() {
        let clock = Clock(lateEvening)
        let session = makeSession(clock)
        let center = NotificationCenter()
        let observer = DayEventObserver(session: session, center: center)

        clock.now = lateEvening.addingTimeInterval(180)
        center.post(name: Notification.Name("something.else"), object: nil)

        #expect(session.host.today.date != oct8)
        withExtendedLifetime(observer) {}
    }

    @Test func aReleasedObserverStopsListening() {
        let clock = Clock(lateEvening)
        let session = makeSession(clock)
        let center = NotificationCenter()
        var observer: DayEventObserver? = DayEventObserver(session: session, center: center)
        #expect(observer != nil)
        observer = nil

        clock.now = lateEvening.addingTimeInterval(180)
        center.post(name: .NSCalendarDayChanged, object: nil)

        #expect(session.host.today.date != oct8)
    }

    @Test func aNotificationPostedOffTheMainThreadIsHandledOnIt() async throws {
        let clock = Clock(lateEvening)
        let session = makeSession(clock)
        let center = NotificationCenter()
        let observer = DayEventObserver(session: session, center: center)
        clock.now = lateEvening.addingTimeInterval(180)

        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                center.post(name: .NSCalendarDayChanged, object: nil)
                continuation.resume()
            }
        }
        for _ in 0..<50 where session.host.today.date != oct8 {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(session.host.today.date == oct8)
        withExtendedLifetime(observer) {}
    }
}
