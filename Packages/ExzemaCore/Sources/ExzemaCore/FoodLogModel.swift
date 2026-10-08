import Foundation
import Observation

/// The state behind one day's food section: the text being typed, its live parse, and the saved lines.
///
/// A match is stored when a line is saved, so what the user sees in the preview is what is kept. Unsaved
/// text and an open edit belong to the date they were typed for and live in `FoodDrafts`.
@MainActor
@Observable
public final class FoodLogModel {
    public let day: Day
    public private(set) var preview: [ParsedItem] = []
    public private(set) var lines: [FoodLine] = []
    public private(set) var errorMessage: String?

    private let store: DayStore
    private let matcher: FoodMatcher
    private let drafts: FoodDrafts

    public init(day: Day, store: DayStore, matcher: FoodMatcher, drafts: FoodDrafts = FoodDrafts()) {
        self.day = day
        self.store = store
        self.matcher = matcher
        self.drafts = drafts
        preview = matcher.parse(drafts.text(for: day.date))
        reload()
    }

    /// The unsaved text for the day on screen.
    public var draft: String { drafts.text(for: day.date) }

    /// The saved line being reopened on this day, or nil when the draft is new.
    public var editing: FoodLineID? { drafts.editing(for: day.date) }

    /// The new entry's text, set aside while a saved line is being edited.
    public var heldNewText: String { editing == nil ? "" : drafts.heldNewText(for: day.date) }

    /// A line with no parsed item would store nothing, so it cannot be saved.
    public var canSave: Bool { !preview.isEmpty }

    public func updateDraft(_ text: String) {
        drafts.setText(text, for: day.date)
        preview = matcher.parse(text)
    }

    /// Saves the draft as a new line, or over the line being edited. On failure the draft is kept.
    public func save() {
        guard canSave else { return }
        do {
            if let editing {
                try store.replaceFoodLine(editing, text: draft, items: preview)
                drafts.endEditing(for: day.date)
            } else {
                try store.addFoodLine(text: draft, items: preview, on: day)
                drafts.clearNewText(for: day.date)
            }
            preview = matcher.parse(draft)
            errorMessage = nil
        } catch {
            errorMessage = "The food could not be saved."
            Log.foodLogging.error("foodLine.saveFailed", private: ["error": String(describing: error)])
        }
        reload()
    }

    /// Opens a saved line. The new entry being typed and any other line's unsaved changes are kept.
    public func beginEditing(_ line: FoodLine) {
        if let open = editing, let openLine = lines.first(where: { $0.id == open }), draft == openLine.text {
            drafts.discardEdit(open, for: day.date)
        }
        drafts.beginEditing(line.id, text: line.text, for: day.date)
        preview = matcher.parse(draft)
        errorMessage = nil
    }

    /// Closes the open edit and drops its changes; the new entry returns to the field.
    public func cancelEditing() {
        drafts.endEditing(for: day.date)
        preview = matcher.parse(draft)
        errorMessage = nil
    }

    /// Deleting a line drops its unsaved changes, ending its edit if open, but only once the delete succeeded.
    public func delete(_ line: FoodLine) {
        guard perform("foodLine.deleteFailed", { try store.deleteFoodLine(line.id) }) else { return }
        drafts.discardEdit(line.id, for: day.date)
        preview = matcher.parse(draft)
    }

    /// Deleting an item changes its line's text, so the line's unsaved changes are dropped once the delete
    /// has succeeded.
    public func delete(_ item: StoredFoodItem) {
        let owner = lines.first { $0.items.contains { $0.id == item.id } }?.id
        guard perform("foodItem.deleteFailed", { try store.deleteFoodItem(item.id) }), let owner else { return }
        drafts.discardEdit(owner, for: day.date)
        preview = matcher.parse(draft)
    }

    public func reload() {
        do {
            lines = try store.foodLines(on: day.date)
        } catch {
            lines = []
            errorMessage = "The saved food could not be read."
            Log.foodLogging.error("foodLines.readFailed", private: ["error": String(describing: error)])
        }
    }

    /// Runs a store change, reloads the lines, and returns whether the change succeeded.
    @discardableResult
    private func perform(_ failureEvent: LogEvent, _ action: () throws -> Void) -> Bool {
        var succeeded = false
        do {
            try action()
            errorMessage = nil
            succeeded = true
        } catch {
            errorMessage = "The change could not be saved."
            Log.foodLogging.error(failureEvent, private: ["error": String(describing: error)])
        }
        reload()
        return succeeded
    }
}
