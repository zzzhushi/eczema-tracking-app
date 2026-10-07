import Foundation
import Testing
@testable import ExzemaCore

private let dataDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "data", directoryHint: .isDirectory)

private func evidence(_ kind: SourceKind, _ level: ChemicalLevel, food: FoodMatch? = nil, form: FormMatch? = nil,
                      source: String = "s") -> Evidence {
    Evidence(sourceId: source, locator: "row", basis: "basis", kind: kind, level: level,
             foodMatch: food, formMatch: form, markers: nil, note: nil)
}

@Suite struct CatalogDataTests {
    @Test func shippedCatalogLoadsAndHasNoIssues() throws {
        let catalog = try Catalog.load(dataDirectory: dataDirectory)
        #expect(catalog.foods.count == 18)
        let issues = catalog.validate()
        #expect(issues.isEmpty, "\(issues.map(\.description).joined(separator: "\n"))")
    }

    @Test func everyAllergenTagIsOnTheFixedList() throws {
        let catalog = try Catalog.load(dataDirectory: dataDirectory)
        #expect(catalog.foods.flatMap(\.allergens).allSatisfy { Allergen.allCases.contains($0) })
    }
}

@Suite struct LevelDerivationTests {
    @Test func levelsOneStepApartTakeTheHigher() {
        #expect(LevelDerivation.result(from: [evidence(.guidance, .low), evidence(.guidance, .moderate)]) == .known(.moderate))
    }

    @Test func levelsMoreThanOneStepApartConflict() {
        let result = LevelDerivation.result(from: [evidence(.guidance, .negligible), evidence(.guidance, .moderate)])
        #expect(result == .unknown(.sourcesConflict))
    }

    @Test func strongerSourceKindDecidesAndWeakerDisagreementIsIgnored() {
        #expect(LevelDerivation.result(from: [evidence(.measurement, .low), evidence(.list, .veryHigh)]) == .known(.low))
    }

    @Test func exactFormOutranksConvertedFormEvenFromAWeakerKind() {
        let result = LevelDerivation.result(from: [evidence(.review, .moderate, form: .converted), evidence(.list, .low)])
        #expect(result == .known(.low))
    }

    @Test func convertedFormOutranksARelatedFood() {
        let result = LevelDerivation.result(from: [evidence(.list, .high, food: .related), evidence(.list, .low, form: .converted)])
        #expect(result == .known(.low))
    }

    @Test func relatedFoodCountsWhenItIsAllThereIs() {
        #expect(LevelDerivation.result(from: [evidence(.list, .high, food: .related)]) == .known(.high))
    }

    @Test func noEvidenceDerivesNothing() {
        #expect(LevelDerivation.result(from: []) == nil)
    }
}

@Suite struct CatalogValidationTests {
    private let racc = Serving(description: "1 cup", grams: 100, origin: .fdaRacc, sourceId: "s", locator: "row",
                               weightSourceId: nil, weightLocator: nil, note: nil)

    private func food(id: String = "rice", aliases: [String] = ["rice"], result: ChemicalResult = .unknown(.notYetResearched),
                      evidence: [Evidence] = [], serving: Serving? = nil) -> Food {
        let assessment = ChemicalAssessment(result: result, evidence: evidence, note: nil)
        return Food(id: id, name: id, description: "", aliases: aliases, varieties: [], allergens: [], serving: serving,
                    chemicals: Dictionary(uniqueKeysWithValues: FoodChemical.allCases.map { ($0, assessment) }))
    }

    private func source(_ id: String) -> Source {
        Source(id: id, type: "web-page", title: "t", authors: nil, journal: nil, publisher: nil, year: nil, doi: nil,
               url: nil, accessedOn: "2026-10-07", note: nil)
    }

    private func catalog(_ foods: [Food], sources: [Source]? = nil) -> Catalog {
        Catalog(manifest: CatalogManifest(schemaVersion: 2, catalogVersion: 1), sources: sources ?? [source("s")], foods: foods)
    }

    @Test func aliasSharedByTwoFoodsIsReported() {
        let issues = catalog([food(id: "a", aliases: ["x"]), food(id: "b", aliases: ["x"])]).validate()
        #expect(issues.contains { $0.message.contains("also belongs to") })
    }

    @Test func uppercaseAliasIsReported() {
        #expect(catalog([food(aliases: ["Rice"])]).validate().contains { $0.message.contains("not lowercase") })
    }

    @Test func knownLevelWithoutEvidenceIsReported() {
        #expect(catalog([food(result: .known(.low))]).validate().contains { $0.message.contains("known without evidence") })
    }

    @Test func knownLevelNeedsAServing() {
        let issues = catalog([food(result: .known(.low), evidence: [evidence(.list, .low)])]).validate()
        #expect(issues.contains { $0.message.contains("no serving") })
    }

    @Test func resultThatContradictsItsEvidenceIsReported() {
        let issues = catalog([food(result: .known(.high), evidence: [evidence(.list, .low)], serving: racc)]).validate()
        #expect(issues.contains { $0.message.contains("but its evidence gives") })
    }

    @Test func evidenceCitingAnUnknownSourceIsReported() {
        let issues = catalog([food(evidence: [evidence(.list, .low, source: "missing")])]).validate()
        #expect(issues.contains { $0.message.contains("unknown source missing") })
    }

    @Test func duplicateSourceIDsAreReported() {
        let issues = catalog([food()], sources: [source("s"), source("s")]).validate()
        #expect(issues.contains { $0.message.contains("duplicate source id s") })
    }

    @Test func servingFromAReferenceNeedsASourceAndLocator() {
        let bare = Serving(description: "1 cup", grams: 100, origin: .fdaRacc, sourceId: nil, locator: nil,
                           weightSourceId: nil, weightLocator: nil, note: nil)
        #expect(catalog([food(serving: bare)]).validate().contains { $0.message.contains("serving needs a source") })
    }

    @Test func estimatedServingNeedsNoSource() {
        let estimate = Serving(description: "1 tsp", grams: 2, origin: .estimate, sourceId: nil, locator: nil,
                               weightSourceId: nil, weightLocator: nil, note: "typical")
        #expect(catalog([food(serving: estimate)]).validate().isEmpty)
    }

    @Test func servingCitingAnUnknownWeightSourceIsReported() {
        var serving = racc
        serving.weightSourceId = "missing"
        #expect(catalog([food(serving: serving)]).validate().contains { $0.message.contains("serving cites unknown source missing") })
    }
}
