import ExzemaCore
import Foundation

extension LocalDate {
    /// Midday on this date in the phone's calendar, for formatting only.
    var displayDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    var weekdayInitial: String {
        displayDate.formatted(.dateTime.weekday(.narrow))
    }

    var longTitle: String {
        displayDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
