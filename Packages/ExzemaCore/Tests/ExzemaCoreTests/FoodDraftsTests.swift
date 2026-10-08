import Foundation
import Testing
import ExzemaCore

@MainActor
@Suite("Food drafts")
struct FoodDraftsTests {
    private let oct6 = LocalDate(year: 2026, month: 10, day: 6)
    private let oct7 = LocalDate(year: 2026, month: 10, day: 7)
    private let lineA = FoodLineID(rawValue: 3)
    private let lineB = FoodLineID(rawValue: 4)

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

        drafts.beginEditing(lineA, text: "", for: oct7)

        #expect(drafts.hasUnsavedWork(on: oct7))
        #expect(drafts.editing(for: oct7) == lineA)
    }

    @Test func startingAnEditSetsTheNewEntryAsideAndEndingItBringsItBack() {
        let drafts = FoodDrafts()
        drafts.setText("a new entry", for: oct7)

        drafts.beginEditing(lineA, text: "rice", for: oct7)
        #expect(drafts.text(for: oct7) == "rice")
        #expect(drafts.heldNewText(for: oct7) == "a new entry")
        drafts.setText("rice and tofu", for: oct7)

        drafts.endEditing(for: oct7)
        #expect(drafts.text(for: oct7) == "a new entry")
        #expect(drafts.editing(for: oct7) == nil)
    }

    @Test func switchingToAnotherLineKeepsTheFirstLinesChanges() {
        let drafts = FoodDrafts()
        drafts.beginEditing(lineA, text: "rice", for: oct7)
        drafts.setText("rice and tofu", for: oct7)

        drafts.beginEditing(lineB, text: "oatmeal", for: oct7)
        #expect(drafts.text(for: oct7) == "oatmeal")
        drafts.beginEditing(lineA, text: "rice", for: oct7)

        #expect(drafts.text(for: oct7) == "rice and tofu", "the changes made to the first line must survive switching away")
    }

    @Test func discardingAnEditForgetsOnlyThatLine() {
        let drafts = FoodDrafts()
        drafts.beginEditing(lineA, text: "rice", for: oct7)
        drafts.setText("rice and tofu", for: oct7)
        drafts.beginEditing(lineB, text: "oatmeal", for: oct7)

        drafts.discardEdit(lineA, for: oct7)
        drafts.beginEditing(lineA, text: "rice", for: oct7)

        #expect(drafts.text(for: oct7) == "rice")
    }

    @Test func clearingTheNewTextLeavesAnOpenEditAlone() {
        let drafts = FoodDrafts()
        drafts.setText("a new entry", for: oct7)
        drafts.beginEditing(lineA, text: "rice", for: oct7)

        drafts.clearNewText(for: oct7)
        drafts.endEditing(for: oct7)

        #expect(drafts.text(for: oct7).isEmpty)
        #expect(drafts.hasUnsavedWork(on: oct7) == false)
    }

    @Test func listsTheDatesThatHaveUnsavedWork() {
        let drafts = FoodDrafts()
        drafts.setText("rice", for: oct7)
        drafts.setText("   ", for: oct6)

        #expect(drafts.datesWithUnsavedWork == [oct7])
    }
}
