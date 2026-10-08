import Foundation
import Testing
import ExzemaCore

@MainActor
@Suite("Day host model")
struct DayHostModelTests {
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    /// A clock the test moves by hand.
    private final class Clock: @unchecked Sendable {
        var now: Date
        var timeZone: TimeZone
        init(_ now: Date, _ timeZone: TimeZone) { self.now = now; self.timeZone = timeZone }
    }

    /// 2026-10-07 23:58 in Los Angeles.
    private let lateEvening = Date(timeIntervalSince1970: 1_791_442_680)

    private func makeModel(_ clock: Clock) -> DayHostModel {
        DayHostModel(clock: { clock.now }, timeZone: { clock.timeZone })
    }

    @Test func startsOnToday() {
        let model = makeModel(Clock(lateEvening, losAngeles))

        #expect(model.day.date == LocalDate(year: 2026, month: 10, day: 7))
        #expect(model.day.timeZoneIdentifier == "America/Los_Angeles")
        #expect(model.isToday && !model.canGoForward)
    }

    @Test func screenKeepsItsDayUntilRefreshedAndThenFollowsTheClockPastMidnight() {
        let clock = Clock(lateEvening, losAngeles)
        let model = makeModel(clock)

        clock.now = lateEvening.addingTimeInterval(180)
        #expect(model.day.date == LocalDate(year: 2026, month: 10, day: 7), "the model changes only when told to refresh")

        model.refresh()
        #expect(model.day.date == LocalDate(year: 2026, month: 10, day: 8))
        #expect(model.isToday)
    }

    @Test func steppingBackPinsTheDayAcrossMidnight() {
        let clock = Clock(lateEvening, losAngeles)
        let model = makeModel(clock)
        model.goBack()
        #expect(model.day.date == LocalDate(year: 2026, month: 10, day: 6))

        clock.now = lateEvening.addingTimeInterval(180)
        model.refresh()

        #expect(model.day.date == LocalDate(year: 2026, month: 10, day: 6), "a day the user chose must not shift under them")
        #expect(model.daysBack == 2)
    }

    @Test func steppingForwardFromYesterdayReturnsToFollowingToday() {
        let clock = Clock(lateEvening, losAngeles)
        let model = makeModel(clock)
        model.goBack()
        #expect(model.canGoForward)

        model.goForward()
        #expect(model.isToday)
        clock.now = lateEvening.addingTimeInterval(180)
        model.refresh()

        #expect(model.day.date == LocalDate(year: 2026, month: 10, day: 8))
    }

    @Test func cannotStepForwardPastToday() {
        let model = makeModel(Clock(lateEvening, losAngeles))
        model.goForward()

        #expect(model.isToday)
        #expect(model.day.date == LocalDate(year: 2026, month: 10, day: 7))
    }

    @Test func stepsBackAcrossMonthAndYearBoundaries() {
        let newYear = Date(timeIntervalSince1970: 1_767_268_800) // 2026-01-01 04:00 in Los Angeles
        let model = makeModel(Clock(newYear, losAngeles))
        model.goBack()

        #expect(model.day.date == LocalDate(year: 2025, month: 12, day: 31))
    }

    @Test func aTimeZoneChangeMovesTodayAndRecordsTheNewZone() {
        let clock = Clock(lateEvening, losAngeles)
        let model = makeModel(clock)

        clock.timeZone = tokyo
        model.refresh()

        #expect(model.day.date == LocalDate(year: 2026, month: 10, day: 8))
        #expect(model.day.timeZoneIdentifier == "Asia/Tokyo")
    }

    @Test func aPinnedDayThatTodayHasCaughtUpWithReturnsToToday() {
        let clock = Clock(lateEvening, tokyo) // 2026-10-08 15:58 in Tokyo
        let model = makeModel(clock)
        model.goBack() // pinned to 2026-10-07

        clock.timeZone = TimeZone(identifier: "Pacific/Honolulu")! // 2026-10-07 20:58, so the pin is now today
        model.refresh()

        #expect(model.isToday)
        #expect(model.day.date == LocalDate(year: 2026, month: 10, day: 7))
    }
}
