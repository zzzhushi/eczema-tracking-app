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

    /// The number of calendar days from `other` to this date; negative when this date is earlier.
    public func days(from other: LocalDate) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = { (date: LocalDate) in DateComponents(year: date.year, month: date.month, day: date.day, hour: 12) }
        return calendar.dateComponents([.day], from: calendar.date(from: components(other))!, to: calendar.date(from: components(self))!).day!
    }
}
