import FoundationModels
import Foundation

/// Prompt v2: describe first, then score. Fields are generated in declaration order, so the
/// observations act as a short written look at the photo before any score is chosen.
@Generable
struct SignScoresV2 {
    @Guide(description: "What is visibly present, where it is, and how extensive it is. Mention swelling or puffiness if present.")
    var observations: String
    @Guide(description: "Redness", .range(0...3)) var redness: Int
    @Guide(description: "Dryness or flaking", .range(0...3)) var drynessFlaking: Int
    @Guide(description: "Bumps or blisters", .range(0...3)) var bumpsBlisters: Int
    @Guide(description: "Cracks or broken skin", .range(0...3)) var cracksBrokenSkin: Int
    @Guide(description: "Thickening", .range(0...3)) var thickening: Int
    @Guide(description: "Oozing or crusting", .range(0...3)) var oozingCrusting: Int
    @Guide(description: "Swelling", .range(0...3)) var swelling: Int
    @Guide(description: "Ids of signs that cannot be judged from the photo")
    var unscorableSigns: [String]

    var values: [Int] { [redness, drynessFlaking, bumpsBlisters, cracksBrokenSkin, thickening, oozingCrusting, swelling] }
}

@Generable
struct PairJudgment {
    @Guide(description: "What visibly differs between the two photos, in one or two sentences")
    var observations: String
    @Guide(description: "Which photo shows more severe eczema", .anyOf(["first", "second", "same"]))
    var worse: String
    @Guide(description: "How much worse: 0 same, 1 slightly, 2 clearly, 3 much worse", .range(0...3))
    var difference: Int
}

extension Rubric {
    private var rubricText: String {
        var text = ""
        for sign in signs {
            text += "\n\(sign.id) (\(sign.name)):"
            for level in ["0", "1", "2", "3"] { text += "\n  \(level) = \(sign.levels[level] ?? "")" }
        }
        return text
    }

    var instructionsV2: String {
        """
        You rate a photo of skin for visible signs of eczema using the rubric below. Work in two steps.
        First write observations: describe only what you can actually see, where it is, and how much of \
        the area it covers. Swelling is one of the signs; score it like the others.
        Then score each sign from 0 to 3 for the most affected area, using exactly the written definitions.
        Rules: give 0 when a sign is not visible. Do not give several signs the same score by default. \
        Reserve 3 for severe findings. List the id of a sign you cannot judge in unscorableSigns and give \
        it 0 as a placeholder. Do not give medical advice.
        \(rubricText)
        """
    }

    var comparisonInstructions: String {
        """
        You compare two photos of skin and judge which shows more severe eczema, using the rubric below \
        for what to look at. Also consider swelling or puffiness. Judge only what is visible, and ignore \
        lighting, background, and clothing. If the difference is too small to be sure, answer same. \
        Do not give medical advice.
        \(rubricText)
        """
    }
}

extension Rater {
    func rateV2(imageURLs: [URL]) async -> RunResult {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let session = LanguageModelSession(instructions: rubric.instructionsV2)
            let prompt = Prompt {
                "Rate the skin in the photo using the rubric."
                for url in imageURLs { Attachment(imageURL: url) }
            }
            let options = greedy ? GenerationOptions(sampling: .greedy) : GenerationOptions()
            let response = try await session.respond(to: prompt, generating: SignScoresV2.self, options: options)
            let ids = ["redness", "dryness-flaking", "bumps-blisters", "cracks-broken-skin", "thickening", "oozing-crusting", "swelling"]
            let scores = zip(ids, response.content.values).map { id, value in
                response.content.unscorableSigns.contains(id) ? nil : value
            }
            var result = RunResult(scores: scores, seconds: seconds(since: start, clock), promptTokens: nil, tokenError: nil, failure: nil)
            result.observations = response.content.observations
            return result
        } catch {
            return RunResult(scores: [], seconds: seconds(since: start, clock), promptTokens: nil, tokenError: nil, failure: Failure.classify(error))
        }
    }

    func compare(first: URL, second: URL) async -> (judgment: PairJudgment?, seconds: Double, failure: String?) {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let session = LanguageModelSession(instructions: rubric.comparisonInstructions)
            let prompt = Prompt {
                "Photo 1:"
                Attachment(imageURL: first)
                "Photo 2:"
                Attachment(imageURL: second)
                "Which photo shows more severe eczema?"
            }
            let options = greedy ? GenerationOptions(sampling: .greedy) : GenerationOptions()
            let response = try await session.respond(to: prompt, generating: PairJudgment.self, options: options)
            return (response.content, seconds(since: start, clock), nil)
        } catch {
            return (nil, seconds(since: start, clock), Failure.classify(error))
        }
    }
}

/// Prompt v3: rate on the user's 0–10 look scale against a photo of the same person's clear skin,
/// so the model judges change from their own baseline instead of absolute colour and texture.
@Generable
struct AnchoredRating {
    @Guide(description: "How the new photo differs from the reference photo, in one or two sentences")
    var differences: String
    @Guide(description: "Regions where the new photo looks different from the reference, such as forehead, eyelids, cheeks, around the mouth, back of hand, fingers, or knuckles. Empty if none.")
    var regions: [String]
    @Guide(description: "How much of the visible skin looks affected", .anyOf(["none", "small area", "some", "most", "nearly all"]))
    var coverage: String
    @Guide(description: "Overall rating from 0 to 10", .range(0...10))
    var overall: Int
}

extension Rubric {
    static let anchoredInstructions = """
        You compare photos of one person's skin. The reference photo shows this person's clear skin: \
        use it as their normal skin tone and texture. Rate the new photo from 0 to 10 by how much it \
        differs from the reference.
        0: looks like the reference.
        1 to 2: slight. Faint redness or dryness in a small area.
        3 to 4: mild. Clearly visible in one or two regions.
        5 to 6: moderate. Clearly red, dry, or bumpy across several regions.
        7 to 8: severe. Widespread redness with flaking, puffiness, or broken skin across most of the area.
        9 to 10: extreme. Raw, oozing, cracked, or swollen across nearly all of the area.
        First describe the differences and list the regions, then give the rating. Ignore lighting, \
        makeup, hair, jewellery, and background. Do not give medical advice.
        """
}

extension Rater {
    func rateAgainst(reference: URL, photo: URL, referenceFirst: Bool) async -> (rating: AnchoredRating?, seconds: Double, failure: String?) {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let session = LanguageModelSession(instructions: Rubric.anchoredInstructions)
            let prompt = Prompt {
                if referenceFirst {
                    "Reference photo of clear skin, rated 0:"
                    Attachment(imageURL: reference)
                    "New photo to rate:"
                    Attachment(imageURL: photo)
                } else {
                    "New photo to rate:"
                    Attachment(imageURL: photo)
                    "Reference photo of clear skin, rated 0:"
                    Attachment(imageURL: reference)
                }
                "Rate the new photo."
            }
            let options = greedy ? GenerationOptions(sampling: .greedy) : GenerationOptions()
            let response = try await session.respond(to: prompt, generating: AnchoredRating.self, options: options)
            return (response.content, seconds(since: start, clock), nil)
        } catch {
            return (nil, seconds(since: start, clock), Failure.classify(error))
        }
    }
}
