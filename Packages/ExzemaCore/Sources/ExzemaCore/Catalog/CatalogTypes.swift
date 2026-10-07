import Foundation

public enum ChemicalLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case negligible, low, moderate, high
    case veryHigh = "very high"

    public static func < (lhs: Self, rhs: Self) -> Bool {
        Self.allCases.firstIndex(of: lhs)! < Self.allCases.firstIndex(of: rhs)!
    }
}

public enum FoodChemical: String, Codable, CaseIterable, Sendable {
    case salicylates, oxalates, amines, histamine, glutamates, nickel
}

public enum Allergen: String, Codable, CaseIterable, Sendable {
    case milk, egg, fish, peanuts, wheat, soy, sesame
    case crustaceanShellfish = "crustacean-shellfish"
    case treeNuts = "tree-nuts"
}

public enum ResearchStatus: String, Codable, Sendable {
    case notYetResearched = "not-yet-researched"
    case researchedNoData = "researched-no-data"
    case sourcesConflict = "sources-conflict"
}

/// Ordered from strongest to weakest.
public enum SourceKind: String, Codable, CaseIterable, Comparable, Sendable {
    case measurement, review, guidance, list

    public static func < (lhs: Self, rhs: Self) -> Bool {
        Self.allCases.firstIndex(of: lhs)! < Self.allCases.firstIndex(of: rhs)!
    }
}

public enum ChemicalResult: Equatable, Sendable {
    case known(ChemicalLevel)
    case unknown(ResearchStatus)
}

extension ChemicalResult: Codable {
    private enum CodingKeys: String, CodingKey { case kind, level, reason }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "known": self = .known(try c.decode(ChemicalLevel.self, forKey: .level))
        case "unknown": self = .unknown(try c.decode(ResearchStatus.self, forKey: .reason))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "unknown result kind \(other)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .known(let level):
            try c.encode("known", forKey: .kind)
            try c.encode(level, forKey: .level)
        case .unknown(let reason):
            try c.encode("unknown", forKey: .kind)
            try c.encode(reason, forKey: .reason)
        }
    }
}

public struct Evidence: Codable, Equatable, Sendable {
    public var sourceId: String
    public var locator: String
    public var basis: String
    public var level: ChemicalLevel
    public var converted: Bool?
    public var note: String?

    public var isConverted: Bool { converted ?? false }
}

public struct ChemicalAssessment: Codable, Equatable, Sendable {
    public var result: ChemicalResult
    public var evidence: [Evidence]
    public var note: String?
}

public enum ServingOrigin: String, Codable, Sendable {
    case fdaRacc = "fda-racc"
    case usdaHousehold = "usda-household"
}

public struct Serving: Codable, Equatable, Sendable {
    public var description: String
    public var grams: Double
    public var origin: ServingOrigin
}

public struct Variety: Codable, Equatable, Sendable {
    public var name: String
    public var `default`: Bool?

    public var isDefault: Bool { `default` ?? false }
}

/// A bibliography entry. `kind` is present only on sources the catalog's evidence cites.
public struct Source: Codable, Equatable, Sendable {
    public var id: String
    public var kind: SourceKind?
    public var type: String
    public var title: String
    public var authors: [String]?
    public var journal: String?
    public var publisher: String?
    public var year: Int?
    public var doi: String?
    public var url: String?
    public var accessedOn: String
    public var note: String?
}

public struct CatalogManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var catalogVersion: Int
}

public struct Food: Equatable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    public var aliases: [String]
    public var varieties: [Variety]
    public var allergens: [Allergen]
    public var serving: Serving?
    public var chemicals: [FoodChemical: ChemicalAssessment]
}

extension Food: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, name, description, aliases, varieties, allergens, serving, chemicals
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decode(String.self, forKey: .description)
        aliases = try c.decode([String].self, forKey: .aliases)
        varieties = try c.decode([Variety].self, forKey: .varieties)
        allergens = try c.decode([Allergen].self, forKey: .allergens)
        serving = try c.decodeIfPresent(Serving.self, forKey: .serving)
        let raw = try c.decode([String: ChemicalAssessment].self, forKey: .chemicals)
        var mapped: [FoodChemical: ChemicalAssessment] = [:]
        for (key, value) in raw {
            guard let chemical = FoodChemical(rawValue: key) else {
                throw DecodingError.dataCorruptedError(forKey: .chemicals, in: c, debugDescription: "unknown chemical \(key)")
            }
            mapped[chemical] = value
        }
        chemicals = mapped
    }
}
