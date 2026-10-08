import Foundation
import Observation

/// Unsaved food text and open edits, kept separately for each date so that neither moves to another day
/// nor is lost when the screen changes day. Held in memory only.
@MainActor
@Observable
public final class FoodDrafts {
    private struct Draft {
        var text = ""
        var editing: FoodLineID?
    }

    private var drafts: [LocalDate: Draft] = [:]

    public init() {}

    public func text(for date: LocalDate) -> String { drafts[date]?.text ?? "" }

    /// The saved line being reopened on `date`, or nil when the text there is new.
    public func editing(for date: LocalDate) -> FoodLineID? { drafts[date]?.editing }

    public func setText(_ text: String, for date: LocalDate) {
        var draft = drafts[date] ?? Draft()
        draft.text = text
        store(draft, for: date)
    }

    public func beginEditing(_ line: FoodLineID, text: String, for date: LocalDate) {
        store(Draft(text: text, editing: line), for: date)
    }

    public func clear(for date: LocalDate) {
        drafts[date] = nil
    }

    /// True when `date` has text beyond whitespace, or an open edit.
    public func hasUnsavedWork(on date: LocalDate) -> Bool {
        guard let draft = drafts[date] else { return false }
        return draft.editing != nil || !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func store(_ draft: Draft, for date: LocalDate) {
        drafts[date] = draft.text.isEmpty && draft.editing == nil ? nil : draft
    }
}
