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

        model.delete(try #require(model.lines.last))
        #expect(model.lines.map(\.text) == ["rice, dragonfruit"])
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
