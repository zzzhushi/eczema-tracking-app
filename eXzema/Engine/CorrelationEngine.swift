import Foundation

struct ExposureRecord: Hashable {
    let day: Date
    let productName: String
    let ingredients: [String]
}

struct EnvironmentRecord: Hashable {
    let day: Date
    let factors: [String]
}

struct FlareRecord: Hashable {
    let day: Date
    let severity: Int
}

enum TriggerKind {
    case ingredient
    case environment
}

struct TriggerScore: Identifiable {
    let kind: TriggerKind
    let ingredient: String
    let products: [String]
    let exposureDayCount: Int
    let flaresPreceded: Int
    let totalFlares: Int
    /// Of the days this factor was present, the share followed by a flare.
    let precision: Double
    /// Of all flares, the share preceded by this factor.
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
        var daysByIngredient: [String: Set<Date>] = [:]
        var productsByIngredient: [String: Set<String>] = [:]
        for exposure in exposures {
            let day = calendar.startOfDay(for: exposure.day)
            for ingredient in exposure.ingredients {
                daysByIngredient[ingredient, default: []].insert(day)
                productsByIngredient[ingredient, default: []].insert(exposure.productName)
            }
        }
        return score(
            daysByFactor: daysByIngredient,
            sourcesByFactor: productsByIngredient,
            flares: flares,
            kind: .ingredient
        )
    }

    /// Scores environmental factors (cold snaps, dry air, …) with the same
    /// precision × coverage math used for ingredients.
    func environmentScores(environments: [EnvironmentRecord], flares: [FlareRecord]) -> [TriggerScore] {
        guard !environments.isEmpty else { return [] }
        var daysByFactor: [String: Set<Date>] = [:]
        for record in environments {
            let day = calendar.startOfDay(for: record.day)
            for factor in record.factors {
                daysByFactor[factor, default: []].insert(day)
            }
        }
        return score(daysByFactor: daysByFactor, sourcesByFactor: [:], flares: flares, kind: .environment)
    }

    private func score(
        daysByFactor: [String: Set<Date>],
        sourcesByFactor: [String: Set<String>],
        flares: [FlareRecord],
        kind: TriggerKind
    ) -> [TriggerScore] {
        let flareDays = Set(flares.map { calendar.startOfDay(for: $0.day) })
        let totalFlares = flareDays.count

        var result: [TriggerScore] = []
        for (factor, factorDays) in daysByFactor {
            let flaresPreceded = flareDays.count(where: { flareDay in
                (0...windowDays).contains { offset in
                    guard let day = calendar.date(byAdding: .day, value: -offset, to: flareDay) else { return false }
                    return factorDays.contains(day)
                }
            })
            let daysFollowedByFlare = factorDays.count(where: { factorDay in
                (0...windowDays).contains { offset in
                    guard let day = calendar.date(byAdding: .day, value: offset, to: factorDay) else { return false }
                    return flareDays.contains(day)
                }
            })
            // Known allergens surface even without a flare association;
            // environment factors only earn a row by preceding a flare.
            let known = kind == .ingredient ? KnownAllergenCatalog.match(factor) : nil
            guard flaresPreceded > 0 || known != nil else { continue }

            let precision = factorDays.isEmpty ? 0 : Double(daysFollowedByFlare) / Double(factorDays.count)
            let coverage = totalFlares == 0 ? 0 : Double(flaresPreceded) / Double(totalFlares)
            result.append(TriggerScore(
                kind: kind,
                ingredient: factor,
                products: sourcesByFactor[factor, default: []].sorted(),
                exposureDayCount: factorDays.count,
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

    static func environmentRecords(_ entries: [EnvironmentEntry]) -> [EnvironmentRecord] {
        entries.compactMap { entry in
            let factors = environmentFactors(entry)
            guard !factors.isEmpty else { return nil }
            return EnvironmentRecord(day: entry.date, factors: factors)
        }
    }

    /// Buckets a raw weather entry into the categorical factors the engine
    /// scores (eczema-relevant extremes, plus the logged condition itself).
    static func environmentFactors(_ entry: EnvironmentEntry) -> [String] {
        var factors: [String] = []
        if let temperature = entry.temperatureC {
            if temperature <= 5 { factors.append("cold weather (≤5 °C)") }
            if temperature >= 27 { factors.append("hot weather (≥27 °C)") }
        }
        if let humidity = entry.humidityPercent {
            if humidity <= 35 { factors.append("dry air (≤35% humidity)") }
            if humidity >= 70 { factors.append("humid air (≥70% humidity)") }
        }
        let conditions = entry.conditions.trimmingCharacters(in: .whitespaces).lowercased()
        if !conditions.isEmpty, conditions != "clear" {
            factors.append(conditions)
        }
        return factors
    }
}
