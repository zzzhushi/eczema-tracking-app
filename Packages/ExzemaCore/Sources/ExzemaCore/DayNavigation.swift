/// Which day the day screen shows, and which days it may open.
///
/// Today is the local calendar date on the phone; days after it cannot be opened.
public struct DayNavigation: Sendable {
    public private(set) var today: LocalDate
    public private(set) var selected: LocalDate

    public init(today: LocalDate) {
        self.today = today
        selected = today
    }

    public func canOpen(_ date: LocalDate) -> Bool {
        date <= today
    }

    /// Select `date` and report whether it was opened; a future date leaves the selection unchanged.
    @discardableResult
    public mutating func select(_ date: LocalDate) -> Bool {
        guard canOpen(date) else { return false }
        selected = date
        return true
    }

    /// Record that the phone's current date is now `newToday`.
    ///
    /// The selection follows today when it was on today, and otherwise stays put so a past day being edited is
    /// not replaced. It never sits after today.
    public mutating func dateChanged(to newToday: LocalDate) {
        let followsToday = selected == today
        today = newToday
        if followsToday || selected > newToday {
            selected = newToday
        }
    }
}
