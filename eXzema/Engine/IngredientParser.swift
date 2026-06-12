import Foundation

/// Turns raw ingredient text (typed, pasted, or OCR'd from a label) into a
/// normalized list of ingredient names so the same ingredient matches across
/// products, the correlation engine, and the allergen catalog.
enum IngredientParser {
    /// Maps common label variants to one canonical spelling.
    private static let aliases: [String: String] = [
        "aqua": "water",
        "eau": "water",
        "parfum": "fragrance",
        "perfume": "fragrance",
        "aroma": "fragrance",
        "oxybenzone": "benzophenone-3",
        "avobenzone": "butyl methoxydibenzoylmethane",
        "octinoxate": "ethylhexyl methoxycinnamate",
        "octyl methoxycinnamate": "ethylhexyl methoxycinnamate",
        "octisalate": "ethylhexyl salicylate",
        "bronopol": "2-bromo-2-nitropropane-1,3-diol",
        "tea tree oil": "melaleuca alternifolia leaf oil",
    ]

    static func parse(_ raw: String) -> [String] {
        var text = raw
        // Strip a leading "Ingredients:" header if present.
        if let range = text.range(of: "ingredients[:\\s]+", options: [.regularExpression, .caseInsensitive]),
           range.lowerBound == text.startIndex {
            text.removeSubrange(range)
        }
        for separator in ["\n", ";", "•", "·", "|"] {
            text = text.replacingOccurrences(of: separator, with: ",")
        }
        var seen = Set<String>()
        var result: [String] = []
        for piece in text.split(separator: ",") {
            let normalized = normalize(String(piece))
            guard normalized.count >= 2, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(normalized)
        }
        return result
    }

    /// Normalizes a single ingredient name: lowercase, trimmed, parentheticals
    /// removed ("Water (Aqua)" -> "water"), aliases applied.
    static func normalize(_ ingredient: String) -> String {
        var name = ingredient.lowercased()
        name = name.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
        name = name.replacingOccurrences(of: "[*.]+", with: " ", options: .regularExpression)
        name = name.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return aliases[name] ?? name
    }
}
