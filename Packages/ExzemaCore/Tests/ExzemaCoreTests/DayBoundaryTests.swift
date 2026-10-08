import Foundation
import Testing
import ExzemaCore

@Suite("Day boundary")
struct DayBoundaryTests {
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func instant(_ iso: String) -> Date {
        try! Date(iso, strategy: .iso8601)
    }

    @Test func dayIsTheLocalCalendarDateEvenWhenUTCIsTheNextDay() {
        let day = Day(loggedAt: instant("2026-10-08T06:30:00Z"), in: losAngeles)

        #expect(day.date == LocalDate(year: 2026, month: 10, day: 7))
    }

    @Test func oneSecondBeforeLocalMidnightBelongsToTheEarlierDay() {
        let day = Day(loggedAt: instant("2026-10-08T06:59:59Z"), in: losAngeles)

        #expect(day.date == LocalDate(year: 2026, month: 10, day: 7))
    }

    @Test func localMidnightStartsTheNextDay() {
        let day = Day(loggedAt: instant("2026-10-08T07:00:00Z"), in: losAngeles)

        #expect(day.date == LocalDate(year: 2026, month: 10, day: 8))
    }

    @Test func theSameInstantFallsOnDifferentDatesInDifferentTimeZones() {
        let moment = instant("2026-10-07T20:00:00Z")

        #expect(Day(loggedAt: moment, in: losAngeles).date == LocalDate(year: 2026, month: 10, day: 7))
        #expect(Day(loggedAt: moment, in: tokyo).date == LocalDate(year: 2026, month: 10, day: 8))
    }

    @Test func dayRecordsTheTimeZoneItWasLoggedIn() {
        let day = Day(loggedAt: instant("2026-10-07T20:00:00Z"), in: tokyo)

        #expect(day.timeZoneIdentifier == "Asia/Tokyo")
    }

    @Test func dayOnAClockChangeIsStillOneCalendarDate() {
        let beforeChange = Day(loggedAt: instant("2026-11-01T08:30:00Z"), in: losAngeles)
        let afterChange = Day(loggedAt: instant("2026-11-01T09:30:00Z"), in: losAngeles)

        #expect(beforeChange.date == afterChange.date, "both sides of the fall-back hour are 1 November")
    }
}
