import ExzemaCore
import SwiftUI

/// The selected day's skin check-in: feel and look for each active area.
struct CheckInSection: View {
    let model: AppModel

    var body: some View {
        ForEach(model.areas, id: \.id) { area in
            Section("\(area.name) skin") {
                RatingRow(
                    title: "Feel",
                    detail: "itch, burning, tightness, pain",
                    value: model.checkIns[area.id]?.feel
                ) { model.setRating(.feel, to: $0, area: area) }
                RatingRow(
                    title: "Look",
                    detail: "redness, dryness, cracks, bumps",
                    value: model.checkIns[area.id]?.look
                ) { model.setRating(.look, to: $0, area: area) }
                PhotoRows(model: model, area: area)
            }
        }
    }
}

/// Eleven buttons for 0–10 with none selected until the user taps one; tapping the selected value clears it.
private struct RatingRow: View {
    let title: String
    let detail: String
    let value: Int?
    let onChange: (Int?) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 6 : DayStore.ratingScale.count
        return Array(repeating: GridItem(.flexible(), spacing: 2), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(DayStore.ratingScale, id: \.self) { number in
                    Button {
                        onChange(value == number ? nil : number)
                    } label: {
                        Text("\(number)")
                            .font(.callout.monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(value == number ? Color.accentColor : Color.secondary.opacity(0.12), in: .rect(cornerRadius: 6))
                            .foregroundStyle(value == number ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(number)")
                    .accessibilityAddTraits(value == number ? .isSelected : [])
                }
            }
            Text("0 clear · 3 mild · 6 moderate · 10 worst ever")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
