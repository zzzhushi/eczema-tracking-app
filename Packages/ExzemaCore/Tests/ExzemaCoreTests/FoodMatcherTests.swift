import Foundation
import Testing
@testable import ExzemaCore

private func food(_ id: String, _ aliases: [String]) -> Food {
    Food(id: id, name: id, description: "", aliases: aliases, varieties: [], allergens: [], serving: nil, chemicals: [:])
}

private let fillerWords: Set<String> = ["and", "with", "a", "the", "some"]

private func matcher(_ foods: [Food], signposter: Signposter = Signpost.shared) -> FoodMatcher {
    FoodMatcher(foods: foods, fillerWords: fillerWords, signposter: signposter)
}

private func matched(_ text: String, _ id: String) -> ParsedItem { ParsedItem(text: text, resolution: .matched(foodID: id)) }
private func unrecognized(_ text: String) -> ParsedItem { ParsedItem(text: text, resolution: .unrecognized) }

@Suite struct FoodMatcherTests {
    private let simple = matcher([
        food("rice", ["rice", "white rice"]),
        food("oatmeal", ["oatmeal", "steel-cut oats"]),
        food("chicken-breast", ["chicken", "chicken breast"]),
        food("chicken-thigh", ["chicken thigh"]),
    ])

    @Test func commaSeparatedFoodsEachMatch() {
        #expect(simple.parse("rice, oatmeal") == [matched("rice", "rice"), matched("oatmeal", "oatmeal")])
    }

    @Test func fillerWordsSeparateFoodsAndAreDropped() {
        #expect(simple.parse("rice and some oatmeal") == [matched("rice", "rice"), matched("oatmeal", "oatmeal")])
    }

    @Test func matchingIgnoresCaseAndKeepsTheTypedSpelling() {
        #expect(simple.parse("White Rice") == [matched("White Rice", "rice")])
    }

    @Test func aMultiWordAliasMatchesAsOneFood() {
        #expect(simple.parse("white rice") == [matched("white rice", "rice")])
    }

    @Test func aHyphenatedAliasIsOneWord() {
        #expect(simple.parse("steel-cut oats") == [matched("steel-cut oats", "oatmeal")])
    }

    @Test(arguments: [
        ("chicken", "chicken-breast"),
        ("chicken breast", "chicken-breast"),
        ("chicken thigh", "chicken-thigh"),
    ])
    func theLongestAliasWins(text: String, foodID: String) {
        #expect(simple.parse(text) == [matched(text, foodID)])
    }

    @Test func aWordWithNoFoodIsKeptAsUnrecognized() {
        #expect(simple.parse("rice, dragonfruit") == [matched("rice", "rice"), unrecognized("dragonfruit")])
    }

    @Test func adjacentUnrecognizedWordsFormOneItem() {
        #expect(simple.parse("dragon fruit and rice") == [unrecognized("dragon fruit"), matched("rice", "rice")])
    }

    @Test func leftoverWordBesideAMatchIsKept() {
        #expect(simple.parse("grilled chicken") == [unrecognized("grilled"), matched("chicken", "chicken-breast")])
    }

    @Test func punctuationAndNewlinesSeparateItems() {
        #expect(simple.parse("rice;oatmeal\nchicken. dragonfruit") ==
            [matched("rice", "rice"), matched("oatmeal", "oatmeal"), matched("chicken", "chicken-breast"), unrecognized("dragonfruit")])
    }

    @Test(arguments: ["", "   ", ",,", "and the", "\n"])
    func textWithNoWordsParsesToNothing(text: String) {
        #expect(simple.parse(text).isEmpty)
    }

    @Test func repeatedFoodsStayAsSeparateItemsInTypedOrder() {
        #expect(simple.parse("rice, oatmeal, rice").map(\.text) == ["rice", "oatmeal", "rice"])
    }

    @Test func parsingIsMarkedWithAMealParsingSignpost() {
        let sink = SignpostTests.RecordingSignpostSink()
        _ = matcher([food("rice", ["rice"])], signposter: Signposter(sink: sink)).parse("rice")
        #expect(sink.events == ["begin mealParsing", "end mealParsing"])
    }
}

@Suite struct ShippedCatalogMatchingTests {
    private func shipped() throws -> (catalog: Catalog, matcher: FoodMatcher) {
        let catalog = try Catalog.load(dataDirectory: shippedDataDirectory)
        let words = try FillerWords.load(dataDirectory: shippedDataDirectory)
        return (catalog, FoodMatcher(foods: catalog.foods, fillerWords: words))
    }

    private static let aliases: [(alias: String, foodID: String)] = {
        guard let catalog = try? Catalog.load(dataDirectory: shippedDataDirectory) else { return [] }
        return catalog.foods.flatMap { food in food.aliases.map { ($0, food.id) } }
    }()

    @Test func theShippedCatalogHasAliasesToCheck() {
        #expect(Self.aliases.count > 50, "the parameterized alias check below would be vacuous")
    }

    @Test(arguments: ShippedCatalogMatchingTests.aliases)
    func everyAliasMatchesItsFood(alias: String, foodID: String) throws {
        let parsed = try shipped().matcher.parse(alias)
        #expect(parsed.map(\.resolution) == [.matched(foodID: foodID)], "'\(alias)' should match only \(foodID)")
    }

    @Test func everyFoodNameWithoutAQualifierMatchesItsFood() throws {
        let (catalog, matcher) = try shipped()
        for food in catalog.foods where !food.name.contains(",") {
            #expect(matcher.parse(food.name).map(\.resolution) == [.matched(foodID: food.id)], "\(food.name) should match \(food.id)")
        }
    }

    @Test(arguments: [
        ("chicken", "chicken-breast"), ("chicken thigh", "chicken-thigh"),
        ("coffee", "coffee-brewed"), ("instant coffee", "coffee-instant"),
        ("fish", "white-fish"), ("cabbage", "green-cabbage"),
    ])
    func plainWordsMatchTheirDefaultFood(text: String, foodID: String) throws {
        #expect(try shipped().matcher.parse(text).map(\.resolution) == [.matched(foodID: foodID)])
    }

    @Test func aWholeDayOfTypedFoodMatchesEachFood() throws {
        let parsed = try shipped().matcher.parse("oatmeal with greek yogurt, 2 eggs, rice and cod. black pepper")
        #expect(parsed.map(\.resolution) == [
            .matched(foodID: "oatmeal"), .matched(foodID: "greek-yogurt"), .unrecognized,
            .matched(foodID: "eggs"), .matched(foodID: "white-rice"), .matched(foodID: "white-fish"), .unrecognized,
        ])
    }

    @Test func fillerWordsAreSingleLowercaseWordsAndNeverAliases() throws {
        let (catalog, _) = try shipped()
        let words = try FillerWords.load(dataDirectory: shippedDataDirectory)
        let aliases = Set(catalog.foods.flatMap(\.aliases))
        #expect(!words.isEmpty)
        for word in words {
            #expect(word == word.lowercased() && !word.contains(" "), "'\(word)' must be one lowercase word")
            #expect(!aliases.contains(word), "'\(word)' is also an alias")
        }
    }
}
