import Foundation

public enum AmountUnit: String, Codable, Sendable {
    case milligrams = "mg"
    case micrograms = "µg"
}

/// A measured or published quantity of a food chemical, kept so the level can be recomputed.
public struct Amount: Codable, Equatable, Sendable {
    public var value: Double
    public var unit: AmountUnit
    /// The portion `value` is stated for, as the source words it.
    public var per: String
    /// Weight of that portion; absent when the source gives only a household measure.
    public var perGrams: Double?

    public init(value: Double, unit: AmountUnit, per: String, perGrams: Double? = nil) {
        self.value = value
        self.unit = unit
        self.per = per
        self.perGrams = perGrams
    }
}

/// The per-serving cutoffs in the analysis rules for chemicals measured as an amount.
public enum ChemicalCutoffs {
    /// The unit the cutoffs for `chemical` use; nil when the chemical has no numeric cutoffs.
    public static func unit(for chemical: FoodChemical) -> AmountUnit? {
        switch chemical {
        case .oxalates, .glutamates: .milligrams
        case .nickel: .micrograms
        case .salicylates, .amines, .histamine: nil
        }
    }

    /// Lower bounds of low, moderate, high, and very high per serving.
    private static func bounds(for chemical: FoodChemical) -> [Double]? {
        switch chemical {
        case .oxalates: [2, 5, 10, 13]
        case .nickel: [1, 10, 20, 50]
        case .glutamates: [14, 140, 280, 700]
        case .salicylates, .amines, .histamine: nil
        }
    }

    /// The amount per serving: scaled by weight when the amount's portion has one, else as published.
    public static func perServing(_ amount: Amount, servingGrams: Double) -> Double {
        guard let perGrams = amount.perGrams, perGrams > 0 else { return amount.value }
        return amount.value * servingGrams / perGrams
    }

    /// Nil when the chemical has no numeric cutoffs or the amount's unit is not the one they use.
    public static func level(for chemical: FoodChemical, amount: Amount, servingGrams: Double) -> ChemicalLevel? {
        guard let bounds = bounds(for: chemical), unit(for: chemical) == amount.unit else { return nil }
        let value = perServing(amount, servingGrams: servingGrams)
        let steps = bounds.filter { value >= $0 }.count
        return ChemicalLevel.allCases[steps]
    }
}
