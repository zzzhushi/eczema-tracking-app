import Foundation

/// Which day the screen shows: today, or some number of days before it. Never a day after today.
///
/// Stored as a distance from today, so a screen left on today follows the clock past midnight.
public struct DaySelection: Equatable, Sendable {
    public private(set) var daysBack = 0

    public init() {}

    public var isToday: Bool { daysBack == 0 }
    public var canGoForward: Bool { daysBack > 0 }

    public mutating func goBack() {
        daysBack += 1
    }

    /// Does nothing on today.
    public mutating func goForward() {
        daysBack = max(0, daysBack - 1)
    }

    /// The selected day, logged in `timeZone`; today is the date shown on the phone at `now`.
    public func day(now: Date, in timeZone: TimeZone) -> Day {
        let today = Day(loggedAt: now, in: timeZone)
        return Day(date: today.date.adding(days: -daysBack), timeZoneIdentifier: timeZone.identifier)
    }
}
