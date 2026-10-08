import Foundation

extension LocalDate {
    /// Return the date `count` calendar days away; negative counts move backwards.
    ///
    /// Arithmetic runs in UTC at noon so a daylight-saving change in the phone's zone can never shift the result.
    public func addingDays(_ count: Int) -> LocalDate {
        let calendar = Self.utcCalendar
        let start = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        let moved = calendar.date(byAdding: .day, value: count, to: start)!
        let parts = calendar.dateComponents([.year, .month, .day], from: moved)
        return LocalDate(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// Days since the Monday that starts this date's week: 0 on Monday, 6 on Sunday.
    var daysSinceMonday: Int {
        let start = Self.utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        let weekday = Self.utcCalendar.component(.weekday, from: start)
        return (weekday + 5) % 7
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}

/// Seven consecutive dates from Monday to Sunday, as shown in the week strip.
public struct Week: Hashable, Sendable {
    public let monday: LocalDate

    /// Create the week that contains `date`.
    public init(containing date: LocalDate) {
        monday = date.addingDays(-date.daysSinceMonday)
    }

    public var days: [LocalDate] {
        (0..<7).map { monday.addingDays($0) }
    }

    public var previous: Week { Week(containing: monday.addingDays(-7)) }
    public var next: Week { Week(containing: monday.addingDays(7)) }
}
