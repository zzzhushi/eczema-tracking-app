import Foundation
import Observation

/// Unsaved food text, kept separately for each date so that it neither moves to another day nor is lost.
///
/// A date holds the text of a new entry and, separately, the changes to any saved lines being edited, so
/// starting, switching, or ending an edit never touches what was typed for the new entry. Held in memory only.
@MainActor
@Observable
public final class FoodDrafts {
    private struct Draft {
        var newText = ""
        var editing: FoodLineID?
        /// Changes to saved lines, kept for every line whose edit was opened and not yet saved or discarded.
        var edits: [FoodLineID: String] = [:]
    }

    private var drafts: [LocalDate: Draft] = [:]

    public init() {}

    /// The text the field shows on `date`: the open edit's text, or else the new entry.
    public func text(for date: LocalDate) -> String {
        guard let draft = drafts[date] else { return "" }
        guard let editing = draft.editing else { return draft.newText }
        return draft.edits[editing] ?? ""
    }

    /// The saved line being edited on `date`, or nil when the field holds a new entry.
    public func editing(for date: LocalDate) -> FoodLineID? { drafts[date]?.editing }

    /// The new entry's text, which stays set aside while an edit is open.
    public func heldNewText(for date: LocalDate) -> String { drafts[date]?.newText ?? "" }

    public func setText(_ text: String, for date: LocalDate) {
        change(date) { draft in
            if let editing = draft.editing {
                draft.edits[editing] = text
            } else {
                draft.newText = text
            }
        }
    }

    /// Opens `line` for editing, starting from `text` unless it already has changes kept.
    public func beginEditing(_ line: FoodLineID, text: String, for date: LocalDate) {
        change(date) { draft in
            draft.editing = line
            if draft.edits[line] == nil { draft.edits[line] = text }
        }
    }

    /// Closes the open edit and forgets its changes; the new entry returns to the field.
    public func endEditing(for date: LocalDate) {
        change(date) { draft in
            if let editing = draft.editing { draft.edits[editing] = nil }
            draft.editing = nil
        }
    }

    /// Forgets the changes kept for `line`, closing its edit if it is open.
    public func discardEdit(_ line: FoodLineID, for date: LocalDate) {
        change(date) { draft in
            draft.edits[line] = nil
            if draft.editing == line { draft.editing = nil }
        }
    }

    public func clearNewText(for date: LocalDate) {
        change(date) { $0.newText = "" }
    }

    /// True when `date` has new text beyond whitespace, or any edit that was opened and not finished.
    public func hasUnsavedWork(on date: LocalDate) -> Bool {
        guard let draft = drafts[date] else { return false }
        return !draft.edits.isEmpty || !draft.newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var datesWithUnsavedWork: Set<LocalDate> {
        Set(drafts.keys.filter { hasUnsavedWork(on: $0) })
    }

    private func change(_ date: LocalDate, _ body: (inout Draft) -> Void) {
        var draft = drafts[date] ?? Draft()
        body(&draft)
        drafts[date] = draft.newText.isEmpty && draft.edits.isEmpty ? nil : draft
    }
}
