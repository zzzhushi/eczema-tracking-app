import Foundation
import Observation

/// The state behind one day's food section: the text being typed, its live parse, and the saved lines.
///
/// A match is stored when a line is saved, so what the user sees in the preview is what is kept.
@MainActor
@Observable
public final class FoodLogModel {
    public let day: Day
    public private(set) var draft = ""
    public private(set) var preview: [ParsedItem] = []
    public private(set) var lines: [FoodLine] = []
    /// The saved line being reopened, or nil when the draft is new.
    public private(set) var editing: FoodLineID?
    public private(set) var errorMessage: String?

    private let store: DayStore
    private let matcher: FoodMatcher

    public init(day: Day, store: DayStore, matcher: FoodMatcher) {
        self.day = day
        self.store = store
        self.matcher = matcher
        reload()
    }

    /// A line with no parsed item would store nothing, so it cannot be saved.
    public var canSave: Bool { !preview.isEmpty }

    public func updateDraft(_ text: String) {
        draft = text
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
            self.editing = nil
            updateDraft("")
            errorMessage = nil
        } catch {
            errorMessage = "The food could not be saved."
            Log.foodLogging.error("foodLine.saveFailed", private: ["error": String(describing: error)])
        }
        reload()
    }

    public func beginEditing(_ line: FoodLine) {
        editing = line.id
        updateDraft(line.text)
        errorMessage = nil
    }

    public func cancelEditing() {
        editing = nil
        updateDraft("")
        errorMessage = nil
    }

    public func delete(_ line: FoodLine) {
        perform("foodLine.deleteFailed") { try store.deleteFoodLine(line.id) }
        if editing == line.id { cancelEditing() }
    }

    public func delete(_ item: StoredFoodItem) {
        perform("foodItem.deleteFailed") { try store.deleteFoodItem(item.id) }
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

    private func perform(_ failureEvent: LogEvent, _ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = "The change could not be saved."
            Log.foodLogging.error(failureEvent, private: ["error": String(describing: error)])
        }
        reload()
    }
}
