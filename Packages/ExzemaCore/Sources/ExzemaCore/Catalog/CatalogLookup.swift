import Foundation

extension ChemicalResult {
    /// The level when it is known. Nil for every research status, so an unknown can never be read as negligible.
    public var level: ChemicalLevel? {
        switch self {
        case .known(let level): level
        case .unknown: nil
        }
    }
}

extension Catalog {
    /// Look up a stored food ID's result for `chemical` in the catalog as it stands now, so research added
    /// later applies to days logged earlier. Nil when no food has that ID.
    public func result(forFoodID id: String, _ chemical: FoodChemical) -> ChemicalResult? {
        food(id: id)?.chemicals[chemical]?.result
    }
}

extension Catalog {
    public func food(id: String) -> Food? {
        foods.first { $0.id == id }
    }
}
