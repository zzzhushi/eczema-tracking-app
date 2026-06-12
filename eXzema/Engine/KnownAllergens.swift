import Foundation

struct KnownAllergen: Codable, Hashable, Identifiable {
    let name: String
    let aliases: [String]
    let category: String
    let note: String

    var id: String { name }
}

/// Reference catalog of well-documented contact allergens and irritants,
/// bundled with the app (Resources/KnownAllergens.json). This is what makes
/// the app eczema-specific without any model training: published allergen
/// lists encoded as data.
enum KnownAllergenCatalog {
    static let all: [KnownAllergen] = load()

    private static let index: [String: KnownAllergen] = {
        var map: [String: KnownAllergen] = [:]
        for allergen in all {
            map[allergen.name] = allergen
            for alias in allergen.aliases {
                map[alias] = allergen
            }
        }
        return map
    }()

    /// Matches a normalized ingredient name against the catalog, exactly or
    /// by containment for multi-word names (e.g. "fragrance (floral)").
    static func match(_ ingredient: String) -> KnownAllergen? {
        let name = IngredientParser.normalize(ingredient)
        if let hit = index[name] { return hit }
        return all.first { allergen in
            ([allergen.name] + allergen.aliases).contains { key in
                key.count >= 6 && name.contains(key)
            }
        }
    }

    private static func load() -> [KnownAllergen] {
        guard let url = Bundle.main.url(forResource: "KnownAllergens", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([KnownAllergen].self, from: data)
        else { return [] }
        return list
    }
}
