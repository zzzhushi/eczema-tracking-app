import ExzemaCore
import SwiftUI

/// One day's food: type a line, check how it parsed beside what was typed, save, and edit or delete what is saved.
///
/// Takes only a day; the store and catalog come from the environment. Produces list sections, so it belongs
/// inside a `List` or `Form`.
struct FoodSectionView: View {
    let day: Day
    @Environment(FoodServices.self) private var services

    var body: some View {
        if let store = services.store, let matching = services.matching {
            FoodSectionContent(day: day, store: store, matching: matching)
        } else {
            Section("Food") {
                Text("Food logging is unavailable.").foregroundStyle(.secondary)
            }
        }
    }
}

private struct FoodSectionContent: View {
    @State private var model: FoodLogModel
    private let day: Day
    private let catalog: Catalog

    init(day: Day, store: DayStore, matching: FoodMatching) {
        _model = State(initialValue: FoodLogModel(day: day, store: store, matcher: matching.matcher))
        self.day = day
        catalog = matching.catalog
    }

    var body: some View {
        content
            .onChange(of: day) { _, newDay in model.show(newDay) }
    }

    @ViewBuilder
    private var content: some View {
        Section("Food") {
            TextField("What did you eat?", text: Binding(get: { model.draft }, set: { model.updateDraft($0) }), axis: .vertical)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(model.editing == nil ? "Save" : "Update") { model.save() }
                            .disabled(!model.canSave)
                    }
                }
            ForEach(Array(model.preview.enumerated()), id: \.offset) { _, item in
                ItemRow(item: item, catalog: catalog)
            }
            HStack {
                Button(model.editing == nil ? "Save" : "Update") { model.save() }
                    .disabled(!model.canSave)
                if model.editing != nil {
                    Button("Cancel", role: .cancel) { model.cancelEditing() }
                }
            }
            .buttonStyle(.borderless)
            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red)
            }
        }
        if !model.lines.isEmpty {
            Section("Logged") {
                ForEach(model.lines, id: \.id) { line in
                    Button { model.beginEditing(line) } label: {
                        Text(line.text).font(.headline)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", role: .destructive) { model.delete(line) }
                    }
                    ForEach(line.items, id: \.id) { stored in
                        ItemRow(item: stored.item, catalog: catalog)
                            .swipeActions {
                                Button("Delete", role: .destructive) { model.delete(stored) }
                            }
                    }
                }
            }
        }
    }
}

/// The typed words beside the food they matched, or a mark that nothing matched.
private struct ItemRow: View {
    let item: ParsedItem
    let catalog: Catalog

    var body: some View {
        LabeledContent(item.text) {
            switch item.resolution {
            case .matched(let foodID):
                Text(catalog.food(id: foodID)?.name ?? foodID)
            case .unrecognized:
                Text("Not recognized").foregroundStyle(.orange)
            }
        }
    }
}
