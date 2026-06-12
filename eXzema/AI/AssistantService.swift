import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AIStatus {
    let available: Bool
    let detail: String
}

struct ProductVerdict {
    let riskLevel: String // "low" | "caution" | "high"
    let summary: String
    let ingredientsOfConcern: [String]
    let suggestions: [String]
    let usedAI: Bool
}

#if canImport(FoundationModels)
@Generable
struct AIProductAssessment {
    @Guide(description: "Overall risk of this product for this specific user. Exactly one of: low, caution, high")
    var riskLevel: String

    @Guide(description: "Two to three sentences in plain language, grounded ONLY in the user's history provided in the prompt. Never diagnose, never give medical advice.")
    var summary: String

    @Guide(description: "Ingredient names from the provided list that are concerning for this specific user")
    var ingredientsOfConcern: [String]

    @Guide(description: "Up to three practical, non-medical suggestions, such as patch testing on a small area or preferring products without a flagged ingredient")
    var suggestions: [String]
}
#endif

/// Wraps Apple's on-device Foundation Models framework. Everything runs
/// locally and free of charge. When the model is unavailable (older device,
/// Apple Intelligence off), every call falls back to a deterministic
/// rule-based verdict so the app works everywhere.
enum AssistantService {
    static func status() -> AIStatus {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return AIStatus(available: true, detail: "On-device Apple Intelligence model is ready. Nothing you log ever leaves this device.")
        case .unavailable(let reason):
            let detail: String
            switch reason {
            case .deviceNotEligible:
                detail = "This device doesn't support Apple Intelligence, so eXzema uses rule-based insights instead."
            case .appleIntelligenceNotEnabled:
                detail = "Apple Intelligence is turned off. Enable it in Settings to get AI summaries."
            case .modelNotReady:
                detail = "The on-device model is still downloading. AI summaries will be available soon."
            @unknown default:
                detail = "On-device AI is currently unavailable, so eXzema uses rule-based insights instead."
            }
            return AIStatus(available: false, detail: detail)
        }
        #else
        return AIStatus(available: false, detail: "On-device AI is not available in this build, so eXzema uses rule-based insights instead.")
        #endif
    }

    static func assess(
        productName: String,
        ingredients: [String],
        personalHits: [TriggerScore],
        knownHits: [KnownAllergen]
    ) async -> ProductVerdict {
        let fallback = ruleBasedVerdict(ingredients: ingredients, personalHits: personalHits, knownHits: knownHits)
        #if canImport(FoundationModels)
        guard case .available = SystemLanguageModel.default.availability else { return fallback }
        do {
            let session = LanguageModelSession(instructions: """
            You are the assistant inside eXzema, a personal eczema tracking app. The user logs \
            products, foods, weather, and flare-ups; a deterministic engine correlates their own \
            history. Your job is to explain that data in plain, supportive language.

            Rules:
            - Ground every statement ONLY in the data provided in the prompt. Never invent \
              ingredient facts or history.
            - You are not a doctor. Never diagnose, never recommend treatments or medications. \
              You may suggest patch testing, avoiding an ingredient, or talking to a dermatologist.
            - Be concise and concrete.
            """)
            let response = try await session.respond(to: prompt(productName: productName, ingredients: ingredients, personalHits: personalHits, knownHits: knownHits), generating: AIProductAssessment.self)
            let assessment = response.content
            let level = ["low", "caution", "high"].contains(assessment.riskLevel.lowercased()) ? assessment.riskLevel.lowercased() : fallback.riskLevel
            return ProductVerdict(
                riskLevel: level,
                summary: assessment.summary,
                ingredientsOfConcern: assessment.ingredientsOfConcern,
                suggestions: assessment.suggestions,
                usedAI: true
            )
        } catch {
            return fallback
        }
        #else
        return fallback
        #endif
    }

    private static func prompt(
        productName: String,
        ingredients: [String],
        personalHits: [TriggerScore],
        knownHits: [KnownAllergen]
    ) -> String {
        var lines: [String] = []
        lines.append("Product under consideration: \(productName.isEmpty ? "Unnamed product" : productName)")
        lines.append("Its ingredients: \(ingredients.joined(separator: ", "))")
        if personalHits.isEmpty {
            lines.append("User history: none of these ingredients has been associated with the user's past flares.")
        } else {
            lines.append("User history (from the correlation engine over the user's own logs):")
            for hit in personalHits {
                lines.append("- \(hit.ingredient): preceded \(hit.flaresPreceded) of \(hit.totalFlares) flares; used on \(hit.exposureDayCount) day(s); association score \(String(format: "%.2f", hit.score)) of 1.0")
            }
        }
        if !knownHits.isEmpty {
            lines.append("Ingredients that are well-documented contact allergens or irritants in general (not specific to this user):")
            for known in knownHits {
                lines.append("- \(known.name): \(known.note)")
            }
        }
        lines.append("Assess the risk of this product for this user.")
        return lines.joined(separator: "\n")
    }

    private static func ruleBasedVerdict(
        ingredients: [String],
        personalHits: [TriggerScore],
        knownHits: [KnownAllergen]
    ) -> ProductVerdict {
        let strongPersonal = personalHits.filter { $0.flaresPreceded >= 2 || $0.score >= 0.25 }
        let riskLevel: String
        if !strongPersonal.isEmpty {
            riskLevel = "high"
        } else if !personalHits.isEmpty || !knownHits.isEmpty {
            riskLevel = "caution"
        } else {
            riskLevel = "low"
        }

        var sentences: [String] = []
        if !strongPersonal.isEmpty {
            let names = strongPersonal.map(\.ingredient).joined(separator: ", ")
            sentences.append("Your history shows a strong association between flares and: \(names).")
        } else if !personalHits.isEmpty {
            let names = personalHits.map(\.ingredient).joined(separator: ", ")
            sentences.append("Some ingredients here have appeared before your past flares: \(names).")
        }
        if !knownHits.isEmpty {
            let names = knownHits.map(\.name).joined(separator: ", ")
            sentences.append("Also contains well-documented contact allergens or irritants: \(names).")
        }
        if sentences.isEmpty {
            sentences.append("Nothing in this ingredient list matches your flare history or the bundled allergen catalog. That is not a guarantee — introduce one new product at a time.")
        }

        var suggestions: [String] = []
        if riskLevel != "low" {
            suggestions.append("Patch test on a small area for a few days before regular use.")
            suggestions.append("Prefer a similar product without the flagged ingredient(s).")
        } else {
            suggestions.append("Introduce it alone (no other new products the same week) so your log stays interpretable.")
        }

        return ProductVerdict(
            riskLevel: riskLevel,
            summary: sentences.joined(separator: " "),
            ingredientsOfConcern: (personalHits.map(\.ingredient) + knownHits.map(\.name)).uniqued(),
            suggestions: suggestions,
            usedAI: false
        )
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
