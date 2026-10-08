import Testing
import ExzemaCore

@Suite("Day navigation")
struct DayNavigationTests {
    private func date(_ day: Int, month: Int = 10) -> LocalDate {
        LocalDate(year: 2026, month: month, day: day)
    }

    @Test func startsOnToday() {
        #expect(DayNavigation(today: date(7)).selected == date(7))
    }

    @Test func pastDaysCanBeOpened() {
        var navigation = DayNavigation(today: date(7))
        let opened = navigation.select(date(1))
        #expect(opened)
        #expect(navigation.selected == date(1))
    }

    @Test func todayCanBeOpened() {
        var navigation = DayNavigation(today: date(7))
        _ = navigation.select(date(1))
        let opened = navigation.select(date(7))
        #expect(opened)
        #expect(navigation.selected == date(7))
    }

    @Test func futureDaysCannotBeOpened() {
        var navigation = DayNavigation(today: date(7))
        #expect(!navigation.canOpen(date(8)))
        let opened = navigation.select(date(8))
        #expect(!opened)
        #expect(navigation.selected == date(7), "a refused selection leaves the current day selected")
    }

    @Test func dayChangeMovesToTheNewTodayWhenViewingToday() {
        var navigation = DayNavigation(today: date(7))
        navigation.dateChanged(to: date(8))
        #expect(navigation.today == date(8))
        #expect(navigation.selected == date(8))
    }

    @Test func dayChangeLeavesAPastDaySelected() {
        var navigation = DayNavigation(today: date(7))
        _ = navigation.select(date(6))
        navigation.dateChanged(to: date(8))
        #expect(navigation.selected == date(6), "the user rating yesterday's skin after midnight stays on yesterday")
        #expect(navigation.today == date(8))
    }

    @Test func dayChangeMakesTheNewTodayOpenable() {
        var navigation = DayNavigation(today: date(7))
        navigation.dateChanged(to: date(8))
        #expect(navigation.canOpen(date(8)))
        #expect(!navigation.canOpen(date(9)))
    }

    @Test func dayChangeToTheSameDateChangesNothing() {
        var navigation = DayNavigation(today: date(7))
        _ = navigation.select(date(3))
        navigation.dateChanged(to: date(7))
        #expect(navigation.selected == date(3))
    }

    @Test func dateMovingBackwardsKeepsASelectedDayThatBecameTheFuture() {
        var navigation = DayNavigation(today: date(7))
        navigation.dateChanged(to: date(5))
        #expect(navigation.selected == date(5), "travelling west can make today earlier; the selection never sits in the future")
    }
}
