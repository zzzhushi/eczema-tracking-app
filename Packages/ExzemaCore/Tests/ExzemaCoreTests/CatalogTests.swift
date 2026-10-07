import Foundation
import Testing
@testable import ExzemaCore

private let dataDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "data", directoryHint: .isDirectory)

private func evidence(_ source: String, _ level: ChemicalLevel, converted: Bool = false) -> Evidence {
    Evidence(sourceId: source, locator: "row", basis: "basis", level: level, converted: converted ? true : nil, note: nil)
}

private let kinds: [String: SourceKind] = ["m": .measurement, "r": .review, "g": .guidance, "l": .list]

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
        let result = LevelDerivation.result(from: [evidence("g", .low), evidence("g", .moderate)], sourceKinds: kinds)
        #expect(result == .known(.moderate))
    }

    @Test func levelsMoreThanOneStepApartConflict() {
        let result = LevelDerivation.result(from: [evidence("g", .negligible), evidence("g", .moderate)], sourceKinds: kinds)
        #expect(result == .unknown(.sourcesConflict))
    }

    @Test func strongerSourceKindDecidesAndWeakerDisagreementIsIgnored() {
        let result = LevelDerivation.result(from: [evidence("m", .low), evidence("l", .veryHigh)], sourceKinds: kinds)
        #expect(result == .known(.low))
    }

    @Test func unconvertedEvidenceOutranksConvertedEvidenceOfAStrongerKind() {
        let result = LevelDerivation.result(
            from: [evidence("r", .moderate, converted: true), evidence("l", .low)], sourceKinds: kinds)
        #expect(result == .known(.low))
    }

    @Test func convertedEvidenceCountsWhenItIsAllThereIs() {
        let result = LevelDerivation.result(from: [evidence("l", .high, converted: true)], sourceKinds: kinds)
        #expect(result == .known(.high))
    }

    @Test func noEvidenceDerivesNothing() {
        #expect(LevelDerivation.result(from: [], sourceKinds: kinds) == nil)
    }
}

@Suite struct CatalogValidationTests {
    private func food(id: String = "rice", aliases: [String] = ["rice"], result: ChemicalResult = .unknown(.notYetResearched),
                      evidence: [Evidence] = [], serving: Serving? = nil) -> Food {
        let assessment = ChemicalAssessment(result: result, evidence: evidence, note: nil)
        return Food(id: id, name: id, description: "", aliases: aliases, varieties: [], allergens: [], serving: serving,
                    chemicals: Dictionary(uniqueKeysWithValues: FoodChemical.allCases.map { ($0, assessment) }))
    }

    private func catalog(_ foods: [Food]) -> Catalog {
        let source = Source(id: "l", kind: .list, type: "web-page", title: "t", authors: nil, journal: nil, publisher: nil,
                            year: nil, doi: nil, url: nil, accessedOn: "2026-10-07", note: nil)
        return Catalog(manifest: CatalogManifest(schemaVersion: 1, catalogVersion: 1), sources: [source], foods: foods)
    }

    @Test func aliasSharedByTwoFoodsIsReported() {
        let issues = catalog([food(id: "a", aliases: ["x"]), food(id: "b", aliases: ["x"])]).validate()
        #expect(issues.contains { $0.message.contains("also belongs to") })
    }

    @Test func uppercaseAliasIsReported() {
        let issues = catalog([food(aliases: ["Rice"])]).validate()
        #expect(issues.contains { $0.message.contains("not lowercase") })
    }

    @Test func knownLevelWithoutEvidenceIsReported() {
        let issues = catalog([food(result: .known(.low))]).validate()
        #expect(issues.contains { $0.message.contains("known without evidence") })
    }

    @Test func knownLevelNeedsAServing() {
        let e = [evidence("l", .low)]
        let issues = catalog([food(result: .known(.low), evidence: e)]).validate()
        #expect(issues.contains { $0.message.contains("no serving") })
    }

    @Test func resultThatContradictsItsEvidenceIsReported() {
        let serving = Serving(description: "1 cup", grams: 100, origin: .fdaRacc)
        let issues = catalog([food(result: .known(.high), evidence: [evidence("l", .low)], serving: serving)]).validate()
        #expect(issues.contains { $0.message.contains("but its evidence gives") })
    }

    @Test func evidenceCitingAnUnknownSourceIsReported() {
        let issues = catalog([food(evidence: [evidence("missing", .low)])]).validate()
        #expect(issues.contains { $0.message.contains("unknown source missing") })
    }
}
