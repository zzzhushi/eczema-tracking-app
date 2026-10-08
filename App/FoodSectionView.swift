import ExzemaCore
import SwiftUI

/// One day's food: type a line, check how it parsed beside what was typed, save, and edit or delete what is saved.
///
/// Takes only a day; the store and catalog come from the environment. Produces list sections, so it belongs
/// inside a `List` or `Form`.
///
/// The content is given the day as its identity, so a new food model is made whenever the day changes. Nothing
/// is lost by that: unsaved text lives in the session's drafts, and saved lines are read from the store.
struct FoodSectionView: View {
    let day: Day
    @Environment(FoodServices.self) private var services

    var body: some View {
        if let store = services.store, let matching = services.matching {
            FoodSectionContent(day: day, store: store, matching: matching, session: services.session)
                .id(day)
        } else {
            Section("Food") {
                Text("Food logging is unavailable.").foregroundStyle(.secondary)
            }
        }
    }
}

private struct FoodSectionContent: View {
    @State private var model: FoodLogModel
    private let catalog: Catalog

    init(day: Day, store: DayStore, matching: FoodMatching, session: DaySession) {
        _model = State(initialValue: session.makeFoodLogModel(for: day, store: store, matcher: matching.matcher))
        catalog = matching.catalog
    }

    var body: some View {
        Section("Food") {
            TextField("What did you eat?", text: Binding(get: { model.draft }, set: { model.updateDraft($0) }), axis: .vertical)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(model.editing == nil ? "Save" : "Update") { model.save() }
                            .disabled(!model.canSave)
                    }
                }
            if !model.preview.isEmpty {
                ForEach(Array(model.preview.enumerated()), id: \.offset) { _, item in
                    ItemRow(item: item, catalog: catalog)
                }
            }
            if model.editing != nil, !model.heldNewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("The new entry you were typing is kept and returns when you finish or cancel.")
                    .font(.caption).foregroundStyle(.secondary)
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
        ForEach(Array(model.lines.enumerated()), id: \.element.id) { index, line in
            Section {
                Button { model.beginEditing(line) } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You typed").font(.caption).foregroundStyle(.secondary)
                            Text(line.text).foregroundStyle(.primary)
                            Text("Matched as").font(.caption).foregroundStyle(.secondary).padding(.top, 10)
                        }
                        Spacer()
                        Image(systemName: "pencil").foregroundStyle(.secondary).accessibilityLabel("Edit")
                    }
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
            } header: {
                Text(model.editing == line.id ? "Entry \(index + 1) · editing" : "Entry \(index + 1)")
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
