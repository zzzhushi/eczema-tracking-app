import Foundation

/// A calendar date with no time of day and no time zone.
public struct LocalDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// The date as `YYYY-MM-DD`: unambiguous, sorts in calendar order, and never digit-grouped like "2,026".
    public var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    init?(isoString: String) {
        let parts = isoString.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }
}

/// A day of the user's life: the local calendar date shown on the phone, and the time zone it was logged in.
public struct Day: Hashable, Sendable {
    public let date: LocalDate
    public let timeZoneIdentifier: String

    public init(date: LocalDate, timeZoneIdentifier: String) {
        self.date = date
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    /// Create the day containing `instant` in `timeZone`, midnight to midnight; never derived from UTC.
    public init(loggedAt instant: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        self.init(
            date: LocalDate(year: parts.year!, month: parts.month!, day: parts.day!),
            timeZoneIdentifier: timeZone.identifier
        )
    }
}
