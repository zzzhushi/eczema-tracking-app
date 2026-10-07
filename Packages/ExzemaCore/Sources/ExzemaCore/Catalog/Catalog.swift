import Foundation

public struct Catalog: Sendable {
    public var manifest: CatalogManifest
    public var sources: [String: Source]
    public var foods: [Food]

    public init(manifest: CatalogManifest, sources: [Source], foods: [Food]) {
        self.manifest = manifest
        self.sources = Dictionary(sources.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.foods = foods
    }

    /// Reads `manifest.json`, `sources.json`, and every file in `foods/` under `directory`.
    public static func load(from directory: URL) throws -> Catalog {
        let decoder = JSONDecoder()
        func read<T: Decodable>(_ type: T.Type, _ url: URL) throws -> T {
            try decoder.decode(type, from: Data(contentsOf: url))
        }
        struct SourceFile: Decodable { var sources: [Source] }
        let manifest = try read(CatalogManifest.self, directory.appending(path: "manifest.json"))
        let sources = try read(SourceFile.self, directory.appending(path: "sources.json")).sources
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
    /// Unconverted evidence outranks converted evidence; within a group the strongest source
    /// kind decides. Levels within one step take the highest; a wider spread is a conflict.
    public static func result(from evidence: [Evidence], sourceKinds: [String: SourceKind]) -> ChemicalResult? {
        guard !evidence.isEmpty else { return nil }
        let unconverted = evidence.filter { !$0.isConverted }
        let pool = unconverted.isEmpty ? evidence : unconverted
        let kinds = pool.compactMap { sourceKinds[$0.sourceId] }
        guard let strongest = kinds.min() else { return nil }
        let levels = pool.filter { sourceKinds[$0.sourceId] == strongest }.map(\.level)
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
        let kinds = sources.mapValues(\.kind)

        var seenIDs = Set<String>()
        var aliasOwner: [String: String] = [:]
        var citedSources = Set<String>()

        for food in foods {
            if !seenIDs.insert(food.id).inserted { issue(food.id, "duplicate id") }
            for alias in food.aliases {
                if alias != alias.lowercased() { issue(food.id, "alias '\(alias)' is not lowercase") }
                if let owner = aliasOwner[alias], owner != food.id { issue(food.id, "alias '\(alias)' also belongs to \(owner)") }
                aliasOwner[alias] = food.id
            }
            if food.varieties.filter(\.isDefault).count > 1 { issue(food.id, "more than one default variety") }

            var anyKnown = false
            for chemical in FoodChemical.allCases {
                guard let assessment = food.chemicals[chemical] else {
                    issue(food.id, "missing \(chemical.rawValue)")
                    continue
                }
                for evidence in assessment.evidence {
                    citedSources.insert(evidence.sourceId)
                    if kinds[evidence.sourceId] == nil { issue(food.id, "\(chemical.rawValue) cites unknown source \(evidence.sourceId)") }
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
                if let derived = LevelDerivation.result(from: assessment.evidence, sourceKinds: kinds), derived != assessment.result {
                    issue(food.id, "\(chemical.rawValue) is \(assessment.result) but its evidence gives \(derived)")
                }
            }
            if anyKnown && food.serving == nil { issue(food.id, "has known levels but no serving") }
        }

        for id in sources.keys where !citedSources.contains(id) { issue(nil, "source \(id) is never cited") }
        return issues.sorted { ($0.foodID ?? "", $0.message) < ($1.foodID ?? "", $1.message) }
    }
}
