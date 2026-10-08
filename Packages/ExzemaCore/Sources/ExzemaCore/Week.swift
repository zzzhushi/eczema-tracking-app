import Foundation

extension LocalDate {
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
        monday = date.adding(days: -date.daysSinceMonday)
    }

    public var days: [LocalDate] {
        (0..<7).map { monday.adding(days: $0) }
    }

    public var previous: Week { Week(containing: monday.adding(days: -7)) }
    public var next: Week { Week(containing: monday.adding(days: 7)) }
}
