import Foundation

extension LocalDate {
    /// The calendar date `days` after this one; negative values go back.
    public func adding(days: Int) -> LocalDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        let moved = calendar.date(byAdding: .day, value: days, to: start)!
        let parts = calendar.dateComponents([.year, .month, .day], from: moved)
        return LocalDate(year: parts.year!, month: parts.month!, day: parts.day!)
    }
}
