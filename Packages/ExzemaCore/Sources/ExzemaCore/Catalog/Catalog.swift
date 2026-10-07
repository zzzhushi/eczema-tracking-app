import Foundation

public struct Catalog: Sendable {
    public var manifest: CatalogManifest
    public var sourceList: [Source]
    public var foods: [Food]

    public init(manifest: CatalogManifest, sources: [Source], foods: [Food]) {
        self.manifest = manifest
        self.sourceList = sources
        self.foods = foods
    }

    /// Sources by ID. The first record wins when IDs repeat; `validate()` reports the repeat.
    public var sources: [String: Source] {
        Dictionary(sourceList.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Reads the shared `sources.json` from `dataDirectory`, and `catalog/manifest.json` and every
    /// file in `catalog/foods/` beneath it.
    public static func load(dataDirectory: URL) throws -> Catalog {
        let decoder = JSONDecoder()
        func read<T: Decodable>(_ type: T.Type, _ url: URL) throws -> T {
            try decoder.decode(type, from: Data(contentsOf: url))
        }
        let directory = dataDirectory.appending(path: "catalog", directoryHint: .isDirectory)
        let manifest = try read(CatalogManifest.self, directory.appending(path: "manifest.json"))
        let sources = try read([Source].self, dataDirectory.appending(path: "sources.json"))
        let foodsDirectory = directory.appending(path: "foods", directoryHint: .isDirectory)
        let foodFiles = try FileManager.default.contentsOfDirectory(at: foodsDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let foods = try foodFiles.map { try read(Food.self, $0) }
        return Catalog(manifest: manifest, sources: sources, foods: foods)
    }
}

/// Applies the catalog-level rules to a chemical's evidence.
public enum LevelDerivation {
    /// Returns nil when there is no evidence to derive from.
    ///
    /// Only the evidence with the closest match to the food and form counts, and within it the
    /// strongest source kind. Levels within one step take the highest; a wider spread is a conflict.
    public static func result(from evidence: [Evidence]) -> ChemicalResult? {
        guard let closest = evidence.map(\.matchTier).min() else { return nil }
        let nearest = evidence.filter { $0.matchTier == closest }
        guard let strongest = nearest.map(\.kind).min() else { return nil }
        let levels = nearest.filter { $0.kind == strongest }.map(\.level)
        guard let highest = levels.max(), let lowest = levels.min() else { return nil }
        let steps = ChemicalLevel.allCases.firstIndex(of: highest)! - ChemicalLevel.allCases.firstIndex(of: lowest)!
        return steps > 1 ? .unknown(.sourcesConflict) : .known(highest)
    }
}

public struct CatalogIssue: Equatable, Sendable, CustomStringConvertible {
    public var foodID: String?
    public var message: String

    public var description: String { "\(foodID ?? "catalog"): \(message)" }
}

extension Catalog {
    /// Checks the data-file rules in the food catalog behavior doc.
    public func validate() -> [CatalogIssue] {
        var issues: [CatalogIssue] = []
        func issue(_ food: String?, _ message: String) { issues.append(CatalogIssue(foodID: food, message: message)) }
        let index = sources

        var seenSources = Set<String>()
        for source in sourceList where !seenSources.insert(source.id).inserted { issue(nil, "duplicate source id \(source.id)") }

        var seenIDs = Set<String>()
        var aliasOwner: [String: String] = [:]

        for food in foods {
            if !seenIDs.insert(food.id).inserted { issue(food.id, "duplicate id") }
            for alias in food.aliases {
                if alias != alias.lowercased() { issue(food.id, "alias '\(alias)' is not lowercase") }
                if let owner = aliasOwner[alias], owner != food.id { issue(food.id, "alias '\(alias)' also belongs to \(owner)") }
                aliasOwner[alias] = food.id
            }
            if food.varieties.filter(\.isDefault).count > 1 { issue(food.id, "more than one default variety") }

            if let serving = food.serving {
                if serving.origin != .estimate {
                    if serving.sourceId == nil || serving.locator == nil { issue(food.id, "serving needs a source and locator") }
                }
                for id in [serving.sourceId, serving.weightSourceId].compactMap({ $0 }) where index[id] == nil {
                    issue(food.id, "serving cites unknown source \(id)")
                }
            }

            var anyKnown = false
            for chemical in FoodChemical.allCases {
                guard let assessment = food.chemicals[chemical] else {
                    issue(food.id, "missing \(chemical.rawValue)")
                    continue
                }
                for evidence in assessment.evidence where index[evidence.sourceId] == nil {
                    issue(food.id, "\(chemical.rawValue) cites unknown source \(evidence.sourceId)")
                }
                switch assessment.result {
                case .known:
                    anyKnown = true
                    if assessment.evidence.isEmpty { issue(food.id, "\(chemical.rawValue) is known without evidence") }
                case .unknown(.sourcesConflict):
                    if assessment.evidence.count < 2 { issue(food.id, "\(chemical.rawValue) conflict needs at least two evidence entries") }
                case .unknown:
                    break
                }
                if let derived = LevelDerivation.result(from: assessment.evidence), derived != assessment.result {
                    issue(food.id, "\(chemical.rawValue) is \(assessment.result) but its evidence gives \(derived)")
                }
            }
            if anyKnown && food.serving == nil { issue(food.id, "has known levels but no serving") }
        }
        return issues.sorted { ($0.foodID ?? "", $0.message) < ($1.foodID ?? "", $1.message) }
    }
}
