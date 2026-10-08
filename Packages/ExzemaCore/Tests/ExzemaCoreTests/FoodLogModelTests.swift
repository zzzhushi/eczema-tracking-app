import Foundation
import Testing
import ExzemaCore

@MainActor
@Suite("Food log model")
struct FoodLogModelTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FoodLogModelTests-\(UUID().uuidString)", isDirectory: true)

    private let day = Day(date: LocalDate(year: 2026, month: 10, day: 7), timeZoneIdentifier: "America/Los_Angeles")
    private let yesterday = Day(date: LocalDate(year: 2026, month: 10, day: 6), timeZoneIdentifier: "America/Los_Angeles")

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func makeStore() throws -> DayStore { try DayStore(at: directory.appendingPathComponent("store.sqlite")) }

    private func makeModel(for day: Day, store: DayStore) throws -> FoodLogModel {
        let matching = try FoodMatching.load(dataDirectory: shippedDataDirectory)
        return FoodLogModel(day: day, store: store, matcher: matching.matcher)
    }

    @Test func typingBuildsALivePreviewOfTheParsedItems() throws {
        let model = try makeModel(for: day, store: makeStore())

        model.updateDraft("rice and dragonfruit")

        #expect(model.preview.map(\.resolution) == [.matched(foodID: "white-rice"), .unrecognized])
        #expect(model.canSave)
    }

    @Test(arguments: ["", "  ", "and the", ","])
    func textWithNoFoodOrWordCannotBeSaved(text: String) throws {
        let model = try makeModel(for: day, store: makeStore())

        model.updateDraft(text)

        #expect(model.canSave == false)
    }

    @Test func savingStoresTheLineWithItsMatchesAndClearsTheDraft() throws {
        let store = try makeStore()
        let model = try makeModel(for: day, store: store)
        model.updateDraft("oatmeal, dragonfruit")

        model.save()

        #expect(model.draft.isEmpty)
        #expect(model.preview.isEmpty)
        #expect(model.lines.map(\.text) == ["oatmeal, dragonfruit"])
        #expect(try store.foodLines(on: day.date).first?.items.map(\.item.resolution) == [.matched(foodID: "oatmeal"), .unrecognized])
        #expect(model.errorMessage == nil)
    }

    @Test func aNewModelShowsWhatWasSavedForItsDay() throws {
        let store = try makeStore()
        let first = try makeModel(for: day, store: store)
        first.updateDraft("rice")
        first.save()

        #expect(try makeModel(for: day, store: store).lines.map(\.text) == ["rice"])
        #expect(try makeModel(for: yesterday, store: store).lines.isEmpty)
    }

    @Test func foodForAnEarlierDayIsSavedUnderThatDay() throws {
        let store = try makeStore()
        let model = try makeModel(for: yesterday, store: store)
        model.updateDraft("rice")

        model.save()

        #expect(try store.foodLines(on: yesterday.date).map(\.text) == ["rice"])
        #expect(try store.foodLines(on: day.date).isEmpty)
    }

    @Test func editingReopensTheLineAndSavingReplacesIt() throws {
        let store = try makeStore()
        let model = try makeModel(for: day, store: store)
        model.updateDraft("rice")
        model.save()
        let line = try #require(model.lines.first)

        model.beginEditing(line)
        #expect(model.draft == "rice")
        #expect(model.editing == line.id)
        model.updateDraft("rice and oatmeal")
        model.save()

        #expect(model.lines.map(\.text) == ["rice and oatmeal"])
        #expect(model.lines.first?.id == line.id)
        #expect(model.editing == nil)
        #expect(model.draft.isEmpty)
    }

    @Test func cancellingAnEditDiscardsTheDraftAndKeepsTheLine() throws {
        let model = try makeModel(for: day, store: makeStore())
        model.updateDraft("rice")
        model.save()
        model.beginEditing(try #require(model.lines.first))
        model.updateDraft("something else")

        model.cancelEditing()

        #expect(model.draft.isEmpty && model.editing == nil)
        #expect(model.lines.map(\.text) == ["rice"])
    }

    @Test func deletingALineAndDeletingAnItemUpdateTheList() throws {
        let model = try makeModel(for: day, store: makeStore())
        model.updateDraft("rice, dragonfruit")
        model.save()
        model.updateDraft("oatmeal")
        model.save()

        let noise = try #require(model.lines.first?.items.last)
        model.delete(noise)
        #expect(model.lines.first?.items.map(\.item.text) == ["rice"])
        #expect(model.lines.first?.text == "rice", "the line text must not name a deleted item")

        model.delete(try #require(model.lines.last))
        #expect(model.lines.map(\.text) == ["rice"])
    }

    @Test func aDeletedItemStaysDeletedWhenTheLineIsReopened() throws {
        let model = try makeModel(for: day, store: makeStore())
        model.updateDraft("rice and dragonfruit")
        model.save()
        model.delete(try #require(model.lines.first?.items.last))
        let line = try #require(model.lines.first)

        model.beginEditing(line)

        #expect(line.text == "rice")
        #expect(model.preview.map(\.text) == ["rice"])
    }

    @Test func deletingTheLineBeingEditedEndsTheEdit() throws {
        let model = try makeModel(for: day, store: makeStore())
        model.updateDraft("rice")
        model.save()
        let line = try #require(model.lines.first)
        model.beginEditing(line)

        model.delete(line)

        #expect(model.editing == nil && model.draft.isEmpty && model.lines.isEmpty)
    }

    @Test func aFailedDeleteOfTheLineBeingEditedKeepsTheDraftAndSaysSo() throws {
        let store = try makeStore()
        let model = try makeModel(for: day, store: store)
        model.updateDraft("rice")
        model.save()
        let line = try #require(model.lines.first)
        model.beginEditing(line)
        model.updateDraft("rice and oatmeal")
        try store.deleteFoodLine(line.id)

        model.delete(line)

        #expect(model.errorMessage != nil)
        #expect(model.editing == line.id)
        #expect(model.draft == "rice and oatmeal", "typed text must survive a failed delete")
    }

    @Test func deletingAnItemOfTheLineBeingEditedEndsTheEdit() throws {
        let model = try makeModel(for: day, store: makeStore())
        model.updateDraft("rice and dragonfruit")
        model.save()
        let line = try #require(model.lines.first)
        model.beginEditing(line)

        model.delete(try #require(line.items.last))

        #expect(model.editing == nil && model.draft.isEmpty)
        #expect(model.lines.first?.text == "rice")
    }

    @Test func eachDayKeepsItsOwnUnsavedText() throws {
        let model = try makeModel(for: day, store: makeStore())
        model.updateDraft("rice")

        model.show(yesterday)
        #expect(model.draft.isEmpty && model.preview.isEmpty)
        model.updateDraft("oatmeal")

        model.show(day)
        #expect(model.draft == "rice")
        model.show(yesterday)
        #expect(model.draft == "oatmeal")
    }

    @Test func savingStoresToTheDayOnScreenAndLeavesTheOtherDaysTextAlone() throws {
        let store = try makeStore()
        let model = try makeModel(for: day, store: store)
        model.updateDraft("rice")
        model.show(yesterday)
        model.updateDraft("oatmeal")

        model.save()

        #expect(try store.foodLines(on: yesterday.date).map(\.text) == ["oatmeal"])
        #expect(try store.foodLines(on: day.date).isEmpty)
        model.show(day)
        #expect(model.draft == "rice")
    }

    @Test func anOpenEditStaysWithItsDayWhileAnotherDayShows() throws {
        let store = try makeStore()
        let model = try makeModel(for: day, store: store)
        model.updateDraft("rice")
        model.save()
        let line = try #require(model.lines.first)
        model.beginEditing(line)
        model.updateDraft("rice and oatmeal")

        model.show(yesterday)
        #expect(model.editing == nil && model.draft.isEmpty)
        model.show(day)
        #expect(model.editing == line.id && model.draft == "rice and oatmeal")
        model.save()

        #expect(try store.foodLines(on: day.date).map(\.text) == ["rice and oatmeal"])
        #expect(model.lines.first?.id == line.id)
    }

    @Test func aModelBuiltAgainOverTheSameDraftsFindsTheTextStillThere() throws {
        let store = try makeStore()
        let drafts = FoodDrafts()
        let matching = try FoodMatching.load(dataDirectory: shippedDataDirectory)
        let first = FoodLogModel(day: day, store: store, matcher: matching.matcher, drafts: drafts)
        first.updateDraft("rice")

        let rebuilt = FoodLogModel(day: day, store: store, matcher: matching.matcher, drafts: drafts)

        #expect(rebuilt.draft == "rice")
        #expect(rebuilt.preview.map(\.resolution) == [.matched(foodID: "white-rice")])
    }

    @Test func startingAnEditKeepsTheNewEntryBeingTypedAndBringsItBack() throws {
        let store = try makeStore()
        let model = try makeModel(for: day, store: store)
        model.updateDraft("rice")
        model.save()
        let line = try #require(model.lines.first)
        model.updateDraft("a new entry of oatmeal")

        model.beginEditing(line)
        #expect(model.draft == "rice")
        #expect(model.heldNewText == "a new entry of oatmeal")
        model.updateDraft("rice and tofu")
        model.save()

        #expect(model.draft == "a new entry of oatmeal", "saving the edit must leave the new entry alone")
        #expect(model.editing == nil && model.heldNewText.isEmpty)
        #expect(try store.foodLines(on: day.date).map(\.text) == ["rice and tofu"])
    }

    @Test func cancellingAnEditBringsTheNewEntryBack() throws {
        let model = try makeModel(for: day, store: makeStore())
        model.updateDraft("rice")
        model.save()
        model.updateDraft("oatmeal")
        model.beginEditing(try #require(model.lines.first))

        model.cancelEditing()

        #expect(model.draft == "oatmeal")
        #expect(model.preview.map(\.text) == ["oatmeal"])
    }

    @Test func tappingASecondLineWhileEditingKeepsTheFirstEditsChanges() throws {
        let model = try makeModel(for: day, store: makeStore())
        model.updateDraft("rice")
        model.save()
        model.updateDraft("oatmeal")
        model.save()
        let first = try #require(model.lines.first)
        let second = try #require(model.lines.last)
        model.beginEditing(first)
        model.updateDraft("rice and tofu")

        model.beginEditing(second)
        #expect(model.draft == "oatmeal")
        model.beginEditing(first)

        #expect(model.draft == "rice and tofu")
    }

    @Test func anEditWithNoChangesIsNotKeptAroundWhenSwitchingAway() throws {
        let drafts = FoodDrafts()
        let store = try makeStore()
        let matching = try FoodMatching.load(dataDirectory: shippedDataDirectory)
        let model = FoodLogModel(day: day, store: store, matcher: matching.matcher, drafts: drafts)
        model.updateDraft("rice")
        model.save()
        model.updateDraft("oatmeal")
        model.save()
        let first = try #require(model.lines.first)
        let second = try #require(model.lines.last)

        model.beginEditing(first)
        model.beginEditing(second)
        model.cancelEditing()

        #expect(drafts.hasUnsavedWork(on: day.date) == false)
    }

    @Test func deletingALineDiscardsItsKeptEdit() throws {
        let drafts = FoodDrafts()
        let store = try makeStore()
        let matching = try FoodMatching.load(dataDirectory: shippedDataDirectory)
        let model = FoodLogModel(day: day, store: store, matcher: matching.matcher, drafts: drafts)
        model.updateDraft("rice")
        model.save()
        model.updateDraft("oatmeal")
        model.save()
        let first = try #require(model.lines.first)
        model.beginEditing(first)
        model.updateDraft("rice and tofu")
        model.beginEditing(try #require(model.lines.last))

        model.delete(first)

        #expect(drafts.hasUnsavedWork(on: day.date) == true, "the line still being edited is unsaved work")
        model.cancelEditing()
        #expect(drafts.hasUnsavedWork(on: day.date) == false, "the deleted line's changes must not linger")
    }

    @Test func movingToAnotherDayShowsThatDaysLines() throws {
        let store = try makeStore()
        let model = try makeModel(for: day, store: store)
        model.updateDraft("rice")
        model.save()

        model.show(yesterday)
        #expect(model.lines.isEmpty)
        model.show(day)

        #expect(model.lines.map(\.text) == ["rice"])
    }

    @Test func aFailedSaveKeepsTheTypedTextAndSaysSo() throws {
        let store = try makeStore()
        let model = try makeModel(for: day, store: store)
        model.updateDraft("rice")
        model.save()
        let line = try #require(model.lines.first)
        model.beginEditing(line)
        try store.deleteFoodLine(line.id)
        model.updateDraft("rice and oatmeal")

        model.save()

        #expect(model.errorMessage != nil)
        #expect(model.draft == "rice and oatmeal", "typed text must survive a failed save")
        #expect(model.lines.isEmpty, "the list must reflect what the store holds")
    }
}
