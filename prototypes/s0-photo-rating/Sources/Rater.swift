import FoundationModels
import Foundation

@Generable
struct SignScores {
    @Guide(description: "Redness", .range(0...3)) var redness: Int
    @Guide(description: "Dryness or flaking", .range(0...3)) var drynessFlaking: Int
    @Guide(description: "Bumps or blisters", .range(0...3)) var bumpsBlisters: Int
    @Guide(description: "Cracks or broken skin", .range(0...3)) var cracksBrokenSkin: Int
    @Guide(description: "Thickening", .range(0...3)) var thickening: Int
    @Guide(description: "Oozing or crusting", .range(0...3)) var oozingCrusting: Int
    @Guide(description: "Ids of signs that cannot be judged from the photo")
    var unscorableSigns: [String]

    var values: [Int] { [redness, drynessFlaking, bumpsBlisters, cracksBrokenSkin, thickening, oozingCrusting] }
}

struct RunResult: Codable {
    var scores: [Int?]
    var seconds: Double
    var promptTokens: Int?
    var tokenError: String?
    var failure: String?
}

enum Failure {
    static func classify(_ error: Error) -> String {
        let text = String(describing: error).lowercased()
        if text.contains("refusal") { return "refusal" }
        if text.contains("guardrail") { return "guardrail" }
        if text.contains("context") { return "context-window" }
        if text.contains("ratelimit") { return "rate-limited" }
        return "other: \(String(describing: type(of: error)))"
    }
}

struct Rater {
    let rubric: Rubric
    var greedy = CommandLine.arguments.contains("-greedy")

    var availability: String {
        switch SystemLanguageModel.default.availability {
        case .available: return "available"
        case .unavailable(let reason): return "unavailable: \(reason)"
        }
    }

    func rate(imageURLs: [URL]) async -> RunResult {
        let clock = ContinuousClock()
        let start = clock.now
        var tokens: Int?
        var tokenError: String?
        do {
            let session = LanguageModelSession(instructions: rubric.instructions)
            let prompt = Prompt {
                "Rate the skin in the first photo using the rubric."
                for url in imageURLs { Attachment(imageURL: url) }
            }
            do { tokens = try await SystemLanguageModel.default.tokenCount(for: prompt) } catch { tokenError = String(describing: error) }
            let options = greedy ? GenerationOptions(sampling: .greedy) : GenerationOptions()
            let response = try await session.respond(to: prompt, generating: SignScores.self, options: options)
            let ids = ["redness", "dryness-flaking", "bumps-blisters", "cracks-broken-skin", "thickening", "oozing-crusting"]
            let scores = zip(ids, response.content.values).map { id, value in
                response.content.unscorableSigns.contains(id) ? nil : value
            }
            return RunResult(scores: scores, seconds: seconds(since: start, clock), promptTokens: tokens, tokenError: tokenError, failure: nil)
        } catch {
            return RunResult(scores: [], seconds: seconds(since: start, clock), promptTokens: tokens, tokenError: tokenError, failure: Failure.classify(error))
        }
    }

    private func seconds(since start: ContinuousClock.Instant, _ clock: ContinuousClock) -> Double {
        let d = clock.now - start
        return Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    }
}
