import Foundation
import Testing
@testable import ExzemaCore

@Suite struct CatalogLookupTests {
    private func food(_ id: String, salicylates: ChemicalResult) -> Food {
        var chemicals: [FoodChemical: ChemicalAssessment] = [:]
        for chemical in FoodChemical.allCases {
            chemicals[chemical] = ChemicalAssessment(result: .unknown(.notYetResearched), evidence: [], note: nil)
        }
        chemicals[.salicylates] = ChemicalAssessment(result: salicylates, evidence: [], note: nil)
        return Food(id: id, name: id, description: "", aliases: [id], varieties: [], allergens: [], serving: nil, chemicals: chemicals)
    }

    private func catalog(_ foods: [Food]) -> Catalog {
        Catalog(manifest: CatalogManifest(schemaVersion: 2, catalogVersion: 1), sources: [], foods: foods)
    }

    @Test func unknownResultHasNoLevelSoItCanNeverReadAsNegligible() {
        let result = catalog([food("rice", salicylates: .unknown(.notYetResearched))]).result(forFoodID: "rice", .salicylates)

        #expect(result == .unknown(.notYetResearched))
        #expect(result?.level == nil)
    }

    @Test func knownResultHasItsLevel() {
        let result = catalog([food("rice", salicylates: .known(.negligible))]).result(forFoodID: "rice", .salicylates)

        #expect(result?.level == .negligible)
    }

    @Test func foodIDMissingFromTheCatalogHasNoResult() {
        #expect(catalog([food("rice", salicylates: .known(.low))]).result(forFoodID: "dragonfruit", .salicylates) == nil)
    }

    @Test func aCatalogUpdateChangesTheLevelOfAnAlreadyStoredFoodID() {
        let storedFoodID = "rice"
        let before = catalog([food(storedFoodID, salicylates: .unknown(.notYetResearched))])
        let after = catalog([food(storedFoodID, salicylates: .known(.low))])

        #expect(before.result(forFoodID: storedFoodID, .salicylates)?.level == nil)
        #expect(after.result(forFoodID: storedFoodID, .salicylates)?.level == .low)
    }
}
