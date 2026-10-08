import Foundation
import Observation

/// The state behind one day's food section: the text being typed, its live parse, and the saved lines.
///
/// A match is stored when a line is saved, so what the user sees in the preview is what is kept. Unsaved
/// text and an open edit belong to the date they were typed for and live in `FoodDrafts`.
@MainActor
@Observable
public final class FoodLogModel {
    public private(set) var day: Day
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
            } else {
                try store.addFoodLine(text: draft, items: preview, on: day)
            }
            drafts.clear(for: day.date)
            preview = []
            errorMessage = nil
        } catch {
            errorMessage = "The food could not be saved."
            Log.foodLogging.error("foodLine.saveFailed", private: ["error": String(describing: error)])
        }
        reload()
    }

    public func beginEditing(_ line: FoodLine) {
        drafts.beginEditing(line.id, text: line.text, for: day.date)
        preview = matcher.parse(line.text)
        errorMessage = nil
    }

    public func cancelEditing() {
        drafts.clear(for: day.date)
        preview = []
        errorMessage = nil
    }

    /// Deleting the line being edited ends the edit, but only once the delete has succeeded.
    public func delete(_ line: FoodLine) {
        guard perform("foodLine.deleteFailed", { try store.deleteFoodLine(line.id) }), editing == line.id else { return }
        cancelEditing()
    }

    /// Deleting an item changes its line's text, so an edit of that line ends once the delete has succeeded.
    public func delete(_ item: StoredFoodItem) {
        let owner = lines.first { $0.items.contains { $0.id == item.id } }?.id
        guard perform("foodItem.deleteFailed", { try store.deleteFoodItem(item.id) }), owner != nil, owner == editing else { return }
        cancelEditing()
    }

    /// Show another day, with that day's own unsaved text and open edit. The day left behind keeps its own.
    public func show(_ newDay: Day) {
        let dateChanged = newDay.date != day.date
        day = newDay
        guard dateChanged else { return }
        preview = matcher.parse(draft)
        errorMessage = nil
        reload()
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
