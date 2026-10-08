import ExzemaCore
import SwiftUI

/// A Monday-to-Sunday strip that pages back by week from the current week.
struct WeekStripView: View {
    let model: AppModel
    @State private var weeksBack = 0

    private static let reach = 1040

    var body: some View {
        let host = model.session.host
        let currentMonday = Week(containing: host.today.date).monday
        let lastOffset = lastOffset(host)
        TabView(selection: $weeksBack) {
            ForEach(-Self.reach...lastOffset, id: \.self) { offset in
                WeekRow(model: model, week: Week(containing: currentMonday.adding(days: offset * 7)))
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 76)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onChange(of: host.shownDate) { _, _ in weeksBack = page(for: host.shownDate, host: host) }
        .onChange(of: host.today.date) { _, _ in weeksBack = page(for: host.shownDate, host: host) }
    }

    /// The last page: the week of the latest of today, the latest date the host can show, and the date on screen.
    /// It is later than today only while a date made a future day by a time zone change holds unsaved work, or
    /// until the host moves off such a date once that work is cleared.
    private func lastOffset(_ host: DayHostModel) -> Int {
        Week.lastOffset(today: host.today.date, latestShowable: host.latestShowableDate, shown: host.shownDate)
    }

    /// The page showing `date`, so the strip follows a date chosen elsewhere (Today, returning after midnight).
    private func page(for date: LocalDate, host: DayHostModel) -> Int {
        min(lastOffset(host), max(-Self.reach, Week.offset(of: date, from: host.today.date)))
    }
}

private struct WeekRow: View {
    let model: AppModel
    let week: Week

    var body: some View {
        let host = model.session.host
        HStack(spacing: 0) {
            ForEach(week.days, id: \.self) { date in
                DayCell(
                    date: date,
                    isSelected: date == host.shownDate,
                    isToday: date == host.today.date,
                    isOpenable: host.canShow(date),
                    hasData: model.savedDates.contains(date)
                ) { host.show(date) }
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct DayCell: View {
    let date: LocalDate
    let isSelected: Bool
    let isToday: Bool
    let isOpenable: Bool
    let hasData: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(date.weekdayInitial).font(.caption).foregroundStyle(.secondary)
                Text("\(date.day)")
                    .font(.body.weight(isToday ? .bold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Color.accentColor : .clear, in: Circle())
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                Circle().fill(hasData ? Color.accentColor : .clear).frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .opacity(isOpenable ? 1 : 0.3)
        }
        .buttonStyle(.plain)
        .disabled(!isOpenable)
        .accessibilityLabel(date.longTitle + (hasData ? ", has data" : ""))
    }
}
