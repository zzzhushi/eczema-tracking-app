import Foundation
import Testing
import ExzemaCore

@Suite("Day selection")
struct DaySelectionTests {
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

    /// 2026-10-07 20:00 in Los Angeles.
    private let evening = Date(timeIntervalSince1970: 1_791_428_400)

    @Test func startsOnToday() {
        let day = DaySelection().day(now: evening, in: losAngeles)

        #expect(day.date == LocalDate(year: 2026, month: 10, day: 7))
        #expect(day.timeZoneIdentifier == "America/Los_Angeles")
    }

    @Test func stepsBackOneDayAtATime() {
        var selection = DaySelection()
        selection.goBack()
        selection.goBack()

        #expect(selection.day(now: evening, in: losAngeles).date == LocalDate(year: 2026, month: 10, day: 5))
    }

    @Test func stepsBackAcrossMonthAndYearBoundaries() {
        let newYear = Date(timeIntervalSince1970: 1_767_268_800) // 2026-01-01 12:00 UTC, 04:00 in Los Angeles
        var selection = DaySelection()
        selection.goBack()

        #expect(selection.day(now: newYear, in: losAngeles).date == LocalDate(year: 2025, month: 12, day: 31))
    }

    @Test func cannotStepForwardPastToday() {
        var selection = DaySelection()
        selection.goForward()

        #expect(selection.canGoForward == false)
        #expect(selection.day(now: evening, in: losAngeles).date == LocalDate(year: 2026, month: 10, day: 7))
    }

    @Test func stepsForwardBackToToday() {
        var selection = DaySelection()
        selection.goBack()
        #expect(selection.canGoForward)

        selection.goForward()

        #expect(selection.isToday)
    }

    @Test func todayFollowsTheClockPastMidnight() {
        let selection = DaySelection()
        let nextMorning = evening.addingTimeInterval(8 * 3600)

        #expect(selection.day(now: nextMorning, in: losAngeles).date == LocalDate(year: 2026, month: 10, day: 8))
    }
}

@Suite("Local date arithmetic")
struct LocalDateArithmeticTests {
    @Test(arguments: [
        (LocalDate(year: 2026, month: 10, day: 7), -1, LocalDate(year: 2026, month: 10, day: 6)),
        (LocalDate(year: 2026, month: 10, day: 1), -1, LocalDate(year: 2026, month: 9, day: 30)),
        (LocalDate(year: 2026, month: 1, day: 1), -1, LocalDate(year: 2025, month: 12, day: 31)),
        (LocalDate(year: 2028, month: 3, day: 1), -1, LocalDate(year: 2028, month: 2, day: 29)),
        (LocalDate(year: 2026, month: 3, day: 8), 1, LocalDate(year: 2026, month: 3, day: 9)),
    ])
    func addingDaysMovesTheCalendarDate(start: LocalDate, days: Int, expected: LocalDate) {
        #expect(start.adding(days: days) == expected)
    }
}
