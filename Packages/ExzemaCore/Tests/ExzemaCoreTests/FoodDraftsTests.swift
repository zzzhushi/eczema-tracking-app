import Foundation
import Testing
import ExzemaCore

@MainActor
@Suite("Food drafts")
struct FoodDraftsTests {
    private let oct6 = LocalDate(year: 2026, month: 10, day: 6)
    private let oct7 = LocalDate(year: 2026, month: 10, day: 7)

    @Test func eachDateKeepsItsOwnText() {
        let drafts = FoodDrafts()
        drafts.setText("rice", for: oct7)
        drafts.setText("oatmeal", for: oct6)

        #expect(drafts.text(for: oct7) == "rice")
        #expect(drafts.text(for: oct6) == "oatmeal")
        #expect(drafts.text(for: LocalDate(year: 2026, month: 10, day: 8)).isEmpty)
    }

    @Test func typedTextIsUnsavedWorkButWhitespaceIsNot() {
        let drafts = FoodDrafts()
        #expect(drafts.hasUnsavedWork(on: oct7) == false)

        drafts.setText("  \n ", for: oct7)
        #expect(drafts.hasUnsavedWork(on: oct7) == false)

        drafts.setText("rice", for: oct7)
        #expect(drafts.hasUnsavedWork(on: oct7))
        #expect(drafts.hasUnsavedWork(on: oct6) == false)
    }

    @Test func anOpenEditIsUnsavedWorkEvenWithEmptyText() {
        let drafts = FoodDrafts()

        drafts.beginEditing(FoodLineID(rawValue: 3), text: "", for: oct7)

        #expect(drafts.hasUnsavedWork(on: oct7))
        #expect(drafts.editing(for: oct7) == FoodLineID(rawValue: 3))
    }

    @Test func clearingADateForgetsItsTextAndEditOnly() {
        let drafts = FoodDrafts()
        drafts.beginEditing(FoodLineID(rawValue: 3), text: "rice", for: oct7)
        drafts.setText("oatmeal", for: oct6)

        drafts.clear(for: oct7)

        #expect(drafts.text(for: oct7).isEmpty && drafts.editing(for: oct7) == nil)
        #expect(drafts.text(for: oct6) == "oatmeal")
    }
}
