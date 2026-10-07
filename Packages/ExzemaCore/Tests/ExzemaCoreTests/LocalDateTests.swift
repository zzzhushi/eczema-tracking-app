import Testing
import ExzemaCore

@Suite("Local date")
struct LocalDateTests {
    @Test func displaysAsAnISODateWithoutDigitGrouping() {
        #expect(LocalDate(year: 2026, month: 10, day: 7).isoString == "2026-10-07")
    }

    @Test func padsSingleDigitMonthsAndDays() {
        #expect(LocalDate(year: 2026, month: 1, day: 5).isoString == "2026-01-05")
    }
}
