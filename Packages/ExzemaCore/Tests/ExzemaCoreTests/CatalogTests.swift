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

    @Test func estimatedServingWithoutANoteIsReported() {
        let estimate = Serving(description: "1 tsp", grams: 2, origin: .estimate, sourceId: nil, locator: nil,
                               weightSourceId: nil, weightLocator: nil, note: nil)
        #expect(catalog([food(serving: estimate)]).validate().contains { $0.message.contains("estimated serving needs a note") })
    }

    @Test func weightSourceWithoutALocatorIsReported() {
        var serving = racc
        serving.weightSourceId = "s"
        #expect(catalog([food(serving: serving)]).validate().contains { $0.message.contains("weight needs both") })
    }

    @Test func weightLocatorWithoutASourceIsReported() {
        var serving = racc
        serving.weightLocator = "row"
        #expect(catalog([food(serving: serving)]).validate().contains { $0.message.contains("weight needs both") })
    }

    @Test func servingCitingAnUnknownWeightSourceIsReported() {
        var serving = racc
        serving.weightSourceId = "missing"
        #expect(catalog([food(serving: serving)]).validate().contains { $0.message.contains("serving cites unknown source missing") })
    }
}

@Suite struct CatalogLoadingTests {
    private func writeCatalog(schemaVersion: Int, foodJSON: String? = nil) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let foods = root.appending(path: "catalog/foods", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: foods, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion": \#(schemaVersion), "catalogVersion": 1}"#.utf8).write(to: root.appending(path: "catalog/manifest.json"))
        try Data("[]".utf8).write(to: root.appending(path: "sources.json"))
        if let foodJSON { try Data(foodJSON.utf8).write(to: foods.appending(path: "x.json")) }
        return root
    }

    private func foodJSON(result: String) -> String {
        let chemical = #"{"result": \#(result), "evidence": []}"#
        let all = FoodChemical.allCases.map { #""\#($0.rawValue)": \#(chemical)"# }.joined(separator: ",")
        return #"{"id": "x", "name": "x", "description": "", "aliases": [], "varieties": [], "allergens": [], "serving": null, "chemicals": {\#(all)}}"#
    }

    @Test func loaderRefusesAnUnsupportedSchemaVersion() throws {
        let root = try writeCatalog(schemaVersion: 99)
        #expect(throws: CatalogError.unsupportedSchema(found: 99, supported: Catalog.supportedSchemaVersion)) {
            try Catalog.load(dataDirectory: root)
        }
    }

    @Test func loaderThrowsWhenTheDataFailsValidation() throws {
        let root = try writeCatalog(schemaVersion: Catalog.supportedSchemaVersion, foodJSON: foodJSON(result: #"{"kind": "known", "level": "low"}"#))
        do {
            _ = try Catalog.load(dataDirectory: root)
            Issue.record("expected the load to fail validation")
        } catch let CatalogError.invalid(issues) {
            #expect(issues.contains { $0.message.contains("known without evidence") })
        }
    }

    @Test func uncheckedLoaderStillReturnsDataThatFailsValidation() throws {
        let root = try writeCatalog(schemaVersion: Catalog.supportedSchemaVersion, foodJSON: foodJSON(result: #"{"kind": "known", "level": "low"}"#))
        #expect(try Catalog.loadUnvalidated(dataDirectory: root).foods.count == 1)
    }

    @Test func loaderAcceptsAValidCatalog() throws {
        let root = try writeCatalog(schemaVersion: Catalog.supportedSchemaVersion,
                                    foodJSON: foodJSON(result: #"{"kind": "unknown", "reason": "not-yet-researched"}"#))
        #expect(try Catalog.load(dataDirectory: root).foods.count == 1)
    }

    @Test func unknownMarkerFailsToDecode() {
        let json = #"{"sourceId": "s", "locator": "row", "basis": "b", "kind": "list", "level": "low", "markers": ["HL"]}"#
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Evidence.self, from: Data(json.utf8)) }
    }

    @Test func everyMarkerInTheShippedDataIsOnTheFixedSet() throws {
        let catalog = try Catalog.load(dataDirectory: dataDirectory)
        let markers = catalog.foods.flatMap { $0.chemicals.values.flatMap(\.evidence) }.flatMap { $0.markers ?? [] }
        #expect(markers.allSatisfy { EvidenceMarker.allCases.contains($0) })
    }
}
