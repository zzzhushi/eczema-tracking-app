import Foundation

struct ExposureRecord: Hashable {
    let day: Date
    let productName: String
    let ingredients: [String]
}

struct FlareRecord: Hashable {
    let day: Date
    let severity: Int
}

struct TriggerScore: Identifiable {
    let ingredient: String
    let products: [String]
    let exposureDayCount: Int
    let flaresPreceded: Int
    let totalFlares: Int
    /// Of the days this ingredient was used, the share followed by a flare.
    let precision: Double
    /// Of all flares, the share preceded by exposure to this ingredient.
    let coverage: Double
    let score: Double
    let knownAllergen: KnownAllergen?

    var id: String { ingredient }
}

/// Deterministic trigger scoring over the user's own logs. No AI involved:
/// same history in, same ranking out. The LLM layer only explains these
/// numbers, it never invents them.
struct CorrelationEngine {
    /// A flare is considered "preceded" by an exposure that happened within
    /// this many days before it (inclusive of the flare day itself).
    var windowDays: Int = 3
    var calendar: Calendar = .current

    func triggerScores(exposures: [ExposureRecord], flares: [FlareRecord]) -> [TriggerScore] {
        guard !exposures.isEmpty else { return [] }
        let flareDays = Set(flares.map { calendar.startOfDay(for: $0.day) })
        let totalFlares = flareDays.count

        var exposureDaysByIngredient: [String: Set<Date>] = [:]
        var productsByIngredient: [String: Set<String>] = [:]
        for exposure in exposures {
            let day = calendar.startOfDay(for: exposure.day)
            for ingredient in exposure.ingredients {
                exposureDaysByIngredient[ingredient, default: []].insert(day)
                productsByIngredient[ingredient, default: []].insert(exposure.productName)
            }
        }

        var result: [TriggerScore] = []
        for (ingredient, exposureDays) in exposureDaysByIngredient {
            let flaresPreceded = flareDays.count(where: { flareDay in
                (0...windowDays).contains { offset in
                    guard let day = calendar.date(byAdding: .day, value: -offset, to: flareDay) else { return false }
                    return exposureDays.contains(day)
                }
            })
            let daysFollowedByFlare = exposureDays.count(where: { exposureDay in
                (0...windowDays).contains { offset in
                    guard let day = calendar.date(byAdding: .day, value: offset, to: exposureDay) else { return false }
                    return flareDays.contains(day)
                }
            })
            let known = KnownAllergenCatalog.match(ingredient)
            guard flaresPreceded > 0 || known != nil else { continue }

            let precision = exposureDays.isEmpty ? 0 : Double(daysFollowedByFlare) / Double(exposureDays.count)
            let coverage = totalFlares == 0 ? 0 : Double(flaresPreceded) / Double(totalFlares)
            result.append(TriggerScore(
                ingredient: ingredient,
                products: productsByIngredient[ingredient, default: []].sorted(),
                exposureDayCount: exposureDays.count,
                flaresPreceded: flaresPreceded,
                totalFlares: totalFlares,
                precision: precision,
                coverage: coverage,
                score: precision * coverage,
                knownAllergen: known
            ))
        }

        return result.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if (lhs.knownAllergen != nil) != (rhs.knownAllergen != nil) { return lhs.knownAllergen != nil }
            return lhs.ingredient < rhs.ingredient
        }
    }
}

/// Converts SwiftData models into the value types the engine consumes.
enum HistoryAssembler {
    static func exposureRecords(_ entries: [ExposureEntry]) -> [ExposureRecord] {
        entries.compactMap { entry in
            guard let product = entry.product else { return nil }
            return ExposureRecord(day: entry.date, productName: product.name, ingredients: product.ingredients)
        }
    }

    static func flareRecords(_ flares: [FlareEvent]) -> [FlareRecord] {
        flares.map { FlareRecord(day: $0.date, severity: $0.severity) }
    }
}
