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
    private let oct5 = LocalDate(year: 2026, month: 10, day: 5)
    private let oct6 = LocalDate(year: 2026, month: 10, day: 6)
    private let oct7 = LocalDate(year: 2026, month: 10, day: 7)
    private let oct8 = LocalDate(year: 2026, month: 10, day: 8)

    private func makeModel(_ clock: Clock) -> DayHostModel {
        DayHostModel(clock: { clock.now }, timeZone: { clock.timeZone })
    }

    @Test func startsOnToday() {
        let model = makeModel(Clock(lateEvening, losAngeles))

        #expect(model.day.date == oct7)
        #expect(model.day.timeZoneIdentifier == "America/Los_Angeles")
        #expect(model.isShowingToday && !model.canGoForward && model.daysBack == 0)
    }

    @Test func midnightLeavesTheScreenOnItsDateAndOnlyChangesWhatTodayIs() {
        let clock = Clock(lateEvening, losAngeles)
        let model = makeModel(clock)

        clock.now = lateEvening.addingTimeInterval(180)
        model.refresh()

        #expect(model.day.date == oct7)
        #expect(model.today.date == oct8)
        #expect(!model.isShowingToday && model.daysBack == 1 && model.canGoForward)
    }

    @Test func aPastDayStaysPutAcrossMidnightAndItsCaptionAges() {
        let clock = Clock(lateEvening, losAngeles)
        let model = makeModel(clock)
        model.goBack()
        model.goBack()
        #expect(model.day.date == oct5 && model.daysBack == 2)

        clock.now = lateEvening.addingTimeInterval(180)
        model.refresh()

        #expect(model.day.date == oct5)
        #expect(model.daysBack == 3)
    }

    @Test func returningAfterTheDateChangedWithNothingUnsavedOpensToday() {
        let clock = Clock(lateEvening, losAngeles)
        let model = makeModel(clock)
        model.wentToBackground()

        clock.now = lateEvening.addingTimeInterval(10 * 3600)
        model.becameActive(hasUnsavedWork: false)

        #expect(model.day.date == oct8)
        #expect(model.isShowingToday)
    }

    @Test func returningAfterTheDateChangedWhileOnAPastDayAlsoOpensToday() {
        let clock = Clock(lateEvening, losAngeles)
        let model = makeModel(clock)
        model.goBack()
        model.goBack()
        model.wentToBackground()

        clock.now = lateEvening.addingTimeInterval(10 * 3600)
        model.becameActive(hasUnsavedWork: false)

        #expect(model.day.date == oct8)
    }

    @Test func returningAfterTheDateChangedWithUnsavedWorkStaysOnThatDay() {
        let clock = Clock(lateEvening, losAngeles)
        let model = makeModel(clock)
        model.wentToBackground()

        clock.now = lateEvening.addingTimeInterval(10 * 3600)
        model.becameActive(hasUnsavedWork: true)

        #expect(model.day.date == oct7)
        #expect(!model.isShowingToday && model.canGoForward)
    }

    @Test func returningOnTheSameDateNeverMovesTheScreen() {
        let clock = Clock(lateEvening, losAngeles)
        let model = makeModel(clock)
        model.goBack()
        model.wentToBackground()

        clock.now = lateEvening.addingTimeInterval(-3600)
        model.becameActive(hasUnsavedWork: false)

        #expect(model.day.date == oct6)
    }

    @Test func aDateThatChangedWhileTheAppWasInFrontDoesNotMoveTheScreenOnTheNextReturn() {
        let clock = Clock(lateEvening, losAngeles)
        let model = makeModel(clock)
        clock.now = lateEvening.addingTimeInterval(180)
        model.refresh()

        model.wentToBackground()
        clock.now = lateEvening.addingTimeInterval(3600)
        model.becameActive(hasUnsavedWork: false)

        #expect(model.day.date == oct7)
    }

    @Test func aTimeZoneChangeLeavesTheScreenAloneAndRecordsTheNewZone() {
        let clock = Clock(lateEvening, losAngeles)
        let model = makeModel(clock)

        clock.timeZone = tokyo
        model.refresh()

        #expect(model.day.date == oct7)
        #expect(model.today.date == oct8)
        #expect(model.day.timeZoneIdentifier == "Asia/Tokyo")
    }

    @Test func aDateThatBecomesTheFutureAfterATimeZoneChangeMovesBackToToday() {
        let clock = Clock(lateEvening, tokyo) // 2026-10-08 15:58 in Tokyo
        let model = makeModel(clock)
        #expect(model.day.date == oct8)

        clock.timeZone = TimeZone(identifier: "Pacific/Honolulu")! // 2026-10-07 20:58
        model.refresh()

        #expect(model.day.date == oct7)
        #expect(model.isShowingToday)
    }

    @Test func forwardStopsAtTodayAndTheTodayButtonJumpsThere() {
        let model = makeModel(Clock(lateEvening, losAngeles))
        model.goForward()
        #expect(model.day.date == oct7)

        model.goBack()
        model.goBack()
        model.goForward()
        #expect(model.day.date == oct6)
        model.goToToday()
        #expect(model.day.date == oct7 && model.isShowingToday)
    }

    @Test func stepsBackAcrossMonthAndYearBoundaries() {
        let newYear = Date(timeIntervalSince1970: 1_767_268_800) // 2026-01-01 04:00 in Los Angeles
        let model = makeModel(Clock(newYear, losAngeles))
        model.goBack()

        #expect(model.day.date == LocalDate(year: 2025, month: 12, day: 31))
    }
}
