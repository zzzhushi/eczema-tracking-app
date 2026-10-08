import Testing
import ExzemaCore

@Suite("Week strip")
struct WeekTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> LocalDate {
        LocalDate(year: year, month: month, day: day)
    }

    @Test func weekStartsOnMondayAndEndsOnSunday() {
        let week = Week(containing: date(2026, 10, 7))
        #expect(week.days.first == date(2026, 10, 5), "Wednesday 7 Oct belongs to the week starting Monday 5 Oct")
        #expect(week.days.last == date(2026, 10, 11))
        #expect(week.days.count == 7)
    }

    @Test func mondayIsItsOwnWeekStart() {
        #expect(Week(containing: date(2026, 10, 5)).days.first == date(2026, 10, 5))
    }

    @Test func sundayBelongsToTheWeekThatStartedSixDaysEarlier() {
        #expect(Week(containing: date(2026, 11, 1)).days.first == date(2026, 10, 26), "a week can span two months")
    }

    @Test func weekSpansTheNewYear() {
        let week = Week(containing: date(2027, 1, 1))
        #expect(week.days.first == date(2026, 12, 28))
        #expect(week.days.last == date(2027, 1, 3))
    }

    @Test func weekIncludesTheLeapDay() {
        let week = Week(containing: date(2028, 2, 29))
        #expect(week.days.first == date(2028, 2, 28))
        #expect(week.days.contains(date(2028, 2, 29)))
        #expect(week.days.last == date(2028, 3, 5))
    }

    @Test func previousAndNextWeeksAreSevenDaysApart() {
        let week = Week(containing: date(2026, 10, 7))
        #expect(week.previous.days.first == date(2026, 9, 28))
        #expect(week.next.days.first == date(2026, 10, 12))
        #expect(week.next.previous == week)
    }

    @Test func addingDaysCrossesMonthAndYearBoundaries() {
        #expect(date(2026, 12, 31).addingDays(1) == date(2027, 1, 1))
        #expect(date(2026, 3, 1).addingDays(-1) == date(2026, 2, 28))
        #expect(date(2028, 3, 1).addingDays(-1) == date(2028, 2, 29))
    }
}
