import Foundation
import Testing
import ExzemaCore

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

    @Test(arguments: [
        (LocalDate(year: 2026, month: 10, day: 7), LocalDate(year: 2026, month: 10, day: 7), 0),
        (LocalDate(year: 2026, month: 10, day: 8), LocalDate(year: 2026, month: 10, day: 7), 1),
        (LocalDate(year: 2026, month: 10, day: 1), LocalDate(year: 2026, month: 9, day: 30), 1),
        (LocalDate(year: 2026, month: 1, day: 1), LocalDate(year: 2025, month: 1, day: 1), 365),
        (LocalDate(year: 2026, month: 10, day: 6), LocalDate(year: 2026, month: 10, day: 7), -1),
    ])
    func daysFromCountsCalendarDaysBetweenDates(later: LocalDate, earlier: LocalDate, expected: Int) {
        #expect(later.days(from: earlier) == expected)
    }
}
