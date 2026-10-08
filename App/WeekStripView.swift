import ExzemaCore
import SwiftUI

/// A Monday-to-Sunday strip that pages back by week from the current week.
struct WeekStripView: View {
    let model: AppModel
    @State private var weeksBack = 0

    private static let reach = 1040

    var body: some View {
        let currentMonday = Week(containing: model.navigation.today).monday
        TabView(selection: $weeksBack) {
            ForEach(-Self.reach...0, id: \.self) { offset in
                WeekRow(model: model, week: Week(containing: currentMonday.addingDays(offset * 7)))
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 76)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onChange(of: model.navigation.today) { _, _ in weeksBack = 0 }
    }
}

private struct WeekRow: View {
    let model: AppModel
    let week: Week

    var body: some View {
        HStack(spacing: 0) {
            ForEach(week.days, id: \.self) { date in
                DayCell(
                    date: date,
                    isSelected: date == model.navigation.selected,
                    isToday: date == model.navigation.today,
                    isOpenable: model.navigation.canOpen(date),
                    hasData: model.savedDates.contains(date)
                ) { model.select(date) }
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
