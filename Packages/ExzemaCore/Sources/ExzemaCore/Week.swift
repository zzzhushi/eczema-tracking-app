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

    /// The number of whole weeks from the week containing `reference` to the week containing `date`; negative
    /// when `date` is earlier.
    public static func offset(of date: LocalDate, from reference: LocalDate) -> Int {
        Week(containing: date).monday.days(from: Week(containing: reference).monday) / 7
    }

    /// The last page of a strip: the week of the latest of today, the latest date that can be shown, and the date
    /// on screen, so the page being viewed never leaves the range when a protected date is cleared.
    public static func lastOffset(today: LocalDate, latestShowable: LocalDate, shown: LocalDate) -> Int {
        max(0, offset(of: latestShowable, from: today), offset(of: shown, from: today))
    }

    public var previous: Week { Week(containing: monday.adding(days: -7)) }
    public var next: Week { Week(containing: monday.adding(days: 7)) }
}
