import FoundationModels
import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreImage
import Vision

/// Experiment variants that rate a photo relative to a reference photo of the same person's clear skin.
enum Variant: String, CaseIterable {
    case overall3, checklist, relative, tiles, perception, relative2, direct3, identical, relative2Boost, rednessBoost, relative2Sampled, relative2BoostSampled, relative7BoostSampled, pairBoost, absoluteBoostSampled, swellingRef, swellingEyes, swellingNoRef, swellGeneralRef, swellRaisedRef, swellGeneralNoRef, swellRaisedNoRef, dryNoRef, dryNoRefDetail, dryRef, dryTilesDetail, flakeCheck, swellRubricRef, swellCues, recipe, recipeB, signOnly, redRel, flakeDensity, latency, batching
}

private let coverageLevels = ["none", "small area", "some", "most", "nearly all"]
private let relativeLevels = ["same", "slightly more", "clearly more", "much more"]
private let commonRules = "Ignore lighting, makeup, hair, jewellery, and background. Do not give medical advice."

@Generable
struct Overall3 {
    @Guide(description: "How the new photo differs from the reference photo, in one or two sentences")
    var differences: String
    @Guide(description: "Overall rating from 0 to 3", .range(0...3))
    var overall: Int
}

@Generable
struct Checklist {
    @Guide(description: "How the new photo differs from the reference photo, in one or two sentences")
    var differences: String
    @Guide(description: "The new photo's skin is redder or pinker than the reference") var redder: Bool
    @Guide(description: "The new photo shows flakes, scales, or peeling skin") var flaking: Bool
    @Guide(description: "The new photo shows bumps or blisters") var bumps: Bool
    @Guide(description: "The new photo shows cracks, scratch marks, or open skin") var brokenSkin: Bool
    @Guide(description: "The new photo's skin looks puffy or swollen compared with the reference") var swelling: Bool
    @Guide(description: "The new photo shows oozing or crusting") var oozingCrusting: Bool
    @Guide(description: "How much of the visible skin looks affected", .anyOf(["none", "small area", "some", "most", "nearly all"]))
    var coverage: String

    var signs: [Bool] { [redder, flaking, bumps, brokenSkin, swelling, oozingCrusting] }
}

@Generable
struct RelativeSigns {
    @Guide(description: "How the new photo differs from the reference photo, in one or two sentences")
    var differences: String
    @Guide(description: "Redness compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var redness: String
    @Guide(description: "Dryness, flaking, or scaling compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var flaking: String
    @Guide(description: "Bumps or blisters compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var bumps: String
    @Guide(description: "Cracks, scratch marks, or open skin compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var brokenSkin: String
    @Guide(description: "Swelling or puffiness compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var swelling: String
    @Guide(description: "Oozing or crusting compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var oozingCrusting: String

    var levels: [Int] { [redness, flaking, bumps, brokenSkin, swelling, oozingCrusting].map { relativeLevels.firstIndex(of: $0) ?? -1 } }
}

@Generable
struct Perception {
    @Guide(description: "The body part shown", .anyOf(["face", "hand", "forearm", "other"]))
    var bodyPart: String
    @Guide(description: "The skin colour, and where any red, pink, dry, or flaky areas are")
    var description: String
    @Guide(description: "Any skin looks red, inflamed, or irritated")
    var anyRedness: Bool
}

@Generable
struct Direct3 {
    @Guide(description: "Overall rating from 0 to 3", .range(0...3))
    var overall: Int
}

@Generable
struct Identity {
    @Guide(description: "Whether the two photos are the same photo")
    var samePhoto: Bool
    @Guide(description: "What differs between the two photos, or none")
    var differences: String
}

/// The seven rubric v1 signs, each relative to the reference, in rubric order.
@Generable
struct RelativeSigns7 {
    @Guide(description: "How the new photo differs from the reference photo, in one or two sentences")
    var differences: String
    @Guide(description: "Redness compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var redness: String
    @Guide(description: "Dryness, flaking, or scaling compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var drynessFlaking: String
    @Guide(description: "Bumps or blisters compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var bumpsBlisters: String
    @Guide(description: "Cracks, scratch marks, or open skin compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var cracksBrokenSkin: String
    @Guide(description: "Thickened, leathery skin with deeper lines compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var thickening: String
    @Guide(description: "Oozing or crusting compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var oozingCrusting: String
    @Guide(description: "Swelling or puffiness compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"])) var swelling: String

    var levels: [Int] { [redness, drynessFlaking, bumpsBlisters, cracksBrokenSkin, thickening, oozingCrusting, swelling].map { relativeLevels.firstIndex(of: $0) ?? -1 } }
}

@Generable
struct PairBoost {
    @Guide(description: "What differs in the skin between the two photos, in one or two sentences")
    var differences: String
    @Guide(description: "Which photo shows more eczema", .anyOf(["first", "second", "same"]))
    var worse: String
}

@Generable
struct SwellingCompared {
    @Guide(description: "The eyelids and the skin under the eyes in the reference photo, in one sentence")
    var reference: String
    @Guide(description: "The eyelids and the skin under the eyes in the new photo, in one sentence")
    var new: String
    @Guide(description: "Swelling in the new photo compared with the reference", .anyOf(["same", "slightly puffier", "clearly puffier", "much puffier"]))
    var swelling: String

    var level: Int { ["same", "slightly puffier", "clearly puffier", "much puffier"].firstIndex(of: swelling) ?? -1 }
}

@Generable
struct SwellingAnywhere {
    @Guide(description: "Where the skin looks puffy, fuller, or raised, or none, in one sentence")
    var description: String
    @Guide(description: "Regions that look swollen, such as eyelids, under the eyes, cheeks, lips, fingers, knuckles, back of the hand, or wrist. Empty if none.")
    var regions: [String]
    @Guide(description: "Swelling", .anyOf(["none", "slight", "clear", "marked"]))
    var swelling: String

    var level: Int { ["none", "slight", "clear", "marked"].firstIndex(of: swelling) ?? -1 }
}

@Generable
struct DrynessAbsolute {
    @Guide(description: "Any flakes or scales lifting from the skin and where they are, or none, in one sentence")
    var flakes: String
    @Guide(description: "Dryness level", .range(0...3))
    var level: Int
}

@Generable
struct DrynessRelative {
    @Guide(description: "Flakes or scales in the new photo compared with the reference, in one sentence")
    var flakes: String
    @Guide(description: "Dryness compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"]))
    var dryness: String

    var level: Int { relativeLevels.firstIndex(of: dryness) ?? -1 }
}

@Generable
struct FlakeCheck {
    @Guide(description: "Any flakes or scales lifting from the skin and where they are, or none, in one sentence")
    var flakes: String
    @Guide(description: "How many flakes or scales are visible", .anyOf(["none", "a few", "many"]))
    var seen: String

    var level: Int { ["none", "a few", "many"].firstIndex(of: seen) ?? -1 }
}

@Generable
struct SwellingRubric {
    @Guide(description: "Where the new photo looks puffier than the reference, or none, in one sentence")
    var description: String
    @Guide(description: "Swelling level", .range(0...3))
    var level: Int
}

@Generable
struct SwellingCues {
    @Guide(description: "How the shape and surface of the skin differ from the reference, in one sentence")
    var description: String
    @Guide(description: "Some area looks fuller or puffier than the same area in the reference") var fuller: Bool
    @Guide(description: "Creases or fine lines that show in the reference are faded or gone in the new photo") var creasesFaded: Bool
    @Guide(description: "The skin looks smoother, stretched, or shinier than in the reference") var stretched: Bool
    @Guide(description: "An outline or opening looks rounder, narrower, or changed in shape compared with the reference") var shapeChanged: Bool

    var count: Int { [fuller, creasesFaded, stretched, shapeChanged].filter { $0 }.count }
}

@Generable
struct SwellingPair {
    @Guide(description: "How the puffiness of the skin differs between the two photos, in one sentence")
    var description: String
    @Guide(description: "Which photo shows more swelling", .anyOf(["first", "second", "same"]))
    var more: String
}

@Generable
struct SignLevel {
    @Guide(description: "What you see for this sign and where, or none, in one sentence")
    var description: String
    @Guide(description: "Level", .range(0...3))
    var level: Int
}

@Generable
struct ThickeningRelative {
    @Guide(description: "How the skin lines look in the new photo compared with the reference, in one sentence")
    var description: String
    @Guide(description: "Thickening, with skin lines exaggerated, compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"]))
    var thickening: String

    var level: Int { relativeLevels.firstIndex(of: thickening) ?? -1 }
}

@Generable
struct SwellingAlone {
    @Guide(description: "The eyelids and the skin under the eyes, in one sentence")
    var eyes: String
    @Guide(description: "Swelling of the eyelids and around the eyes", .anyOf(["none", "slight", "clear", "marked"]))
    var swelling: String

    var level: Int { ["none", "slight", "clear", "marked"].firstIndex(of: swelling) ?? -1 }
}

@Generable
struct RednessOnly {
    @Guide(description: "How the redness of the new photo differs from the reference, in one sentence")
    var differences: String
    @Guide(description: "Redness compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"]))
    var redness: String

    var level: Int { relativeLevels.firstIndex(of: redness) ?? -1 }
}

enum AnchoredPrompts {
    static let swellingRef = """
        You compare swelling in a new photo of one person's face with a reference photo of the same \
        face on a clear day. Look at the eyelids, the skin under the eyes, and the outline of the \
        cheeks. Swollen eyelids look puffy, hide the eyelid crease, and make the eye opening narrower. \
        Describe the eyelids in each photo first. Answer same unless the new photo is clearly puffier. \
        Ignore expression, angle, lighting, makeup, hair, and background. Do not give medical advice.
        """
    static let swellingEyes = """
        You compare swelling in two close-up crops of the eye area of one person's face: a reference \
        crop from a clear day and a new crop. Swollen eyelids look puffy, hide the eyelid crease, and \
        make the eye opening narrower. Describe the eyelids in each crop first. Answer same unless the \
        new crop is clearly puffier. Ignore expression, angle, lighting, makeup, and hair. Do not give \
        medical advice.
        """
    static let swellingNoRef = """
        You rate swelling around the eyes in a photo of a face. Swollen eyelids look puffy, hide the \
        eyelid crease, and make the eye opening narrower. Describe the eyelids and the skin under the \
        eyes first, then choose:
        none: normal contours.
        slight: slight puffiness, barely visible.
        clear: clearly puffy, contours softened.
        marked: marked swelling that narrows the eye opening.
        Ignore expression, angle, lighting, makeup, hair, and background. Do not give medical advice.
        """
    static let swellingGeneral = """
        Swelling is skin that looks puffy, fuller, or raised, so natural contours soften: creases and \
        fine wrinkles fade, outlines look rounder, and openings such as the eyes look narrower. It can \
        appear wherever eczema is, such as the eyelids, under the eyes, cheeks, lips, fingers, \
        knuckles, the back of the hand, or the wrist.
        """
    static let swellingRaised = """
        Swelling is affected skin that sits raised or puffy above the surrounding skin instead of \
        lying flat, often with blurred edges. Look for any area that looks raised, fuller, or puffy, \
        wherever it is.
        """
    static let swellingScale = """
        none: normal contours.
        slight: slight puffiness, barely visible.
        clear: clearly puffy, contours softened.
        marked: marked swelling that distorts contours.
        Ignore expression, angle, lighting, makeup, hair, jewellery, and background. Do not give medical advice.
        """
    static func swellingWithReference(_ definition: String) -> String {
        "You compare swelling in a new photo of one person's skin with a reference photo of the same area on a clear day. "
            + definition + "\nDescribe where the new photo looks puffier than the reference, then choose a level. "
            + "Choose none if it is no puffier than the reference.\n" + swellingScale
    }
    static func swellingAlone(_ definition: String) -> String {
        "You rate swelling in a photo of skin. " + definition
            + "\nDescribe where the skin looks swollen, then choose a level.\n" + swellingScale
    }
    static let pair = """
        You compare two photos of the same area of one person's skin, taken at different times. \
        Decide which photo shows more eczema: more redness, dryness or flaking, bumps, broken skin, \
        thickening, oozing or crusting, or swelling. The photos are often about the same. Answer same \
        unless you can see a specific spot where one photo is clearly worse. Describe the differences \
        first. \(commonRules)
        """
    static let rednessOnly = """
        You compare a new photo of one person's skin with a reference photo of their clear skin, \
        which shows their normal skin tone. The new photo is often the same as the reference. Judge \
        only redness: answer same unless some skin in the new photo is clearly redder than anywhere \
        in the reference, then say slightly more, clearly more, or much more. Describe the difference \
        first. \(commonRules)
        """
    static let relative2 = """
        You compare a new photo of one person's skin with a reference photo of their clear skin, \
        which shows their normal skin tone and texture. The new photo is often the same as the \
        reference. For each sign, answer same unless you can see a specific spot in the new photo \
        where the sign is clearly stronger than anywhere in the reference. Then say slightly more, \
        clearly more, or much more. Describe the differences first. \(commonRules)
        """
    static let direct3 = """
        You compare a new photo of one person's skin with a reference photo of their clear skin, \
        which shows their normal skin tone and texture. Rate the new photo from 0 to 3.
        0: no visible difference from the reference. This is the most common answer.
        1: mild. Slight redness or dryness in one or a few small spots.
        2: moderate. Clearly red, dry, or bumpy patches.
        3: severe. Red, inflamed skin across much of the area, often with flaking, puffiness, or broken skin.
        \(commonRules)
        """
    static let identical = "You compare two photos and say whether they are the same photo. Answer from what is visible."
    static let overall3 = """
        You compare photos of one person's skin. The reference photo shows this person's clear skin: \
        use it as their normal skin tone and texture. Rate the new photo from 0 to 3 by how much it \
        differs from the reference.
        0: looks like the reference.
        1: mild. Slight redness or dryness in one or a few small spots.
        2: moderate. Clearly red, dry, or bumpy patches.
        3: severe. Red, inflamed skin across much of the area, often with flaking, puffiness, or broken skin.
        Describe the differences first, then rate. \(commonRules)
        """
    static let checklist = """
        You compare a new photo of one person's skin with a reference photo of their clear skin, \
        which shows their normal skin tone and texture. Describe the differences, then answer each \
        question about the new photo compared with the reference, from what is visible. \(commonRules)
        """
    static let relative = """
        You compare a new photo of one person's skin with a reference photo of their clear skin, \
        which shows their normal skin tone and texture. Describe the differences, then say for each \
        sign whether the new photo shows the same as the reference, slightly more, clearly more, or \
        much more. \(commonRules)
        """
    static let tile = """
        You compare part of a photo of one person's skin with a reference photo of their clear skin, \
        which shows their normal skin tone and texture. The part may show skin, background, or both. \
        Rate the skin in the part from 0 to 3 by how much it differs from the reference; rate 0 if it \
        shows no skin.
        0: looks like the reference.
        1: mild. Slight redness or dryness.
        2: moderate. Clearly red, dry, or bumpy.
        3: severe. Red, inflamed skin, often with flaking, puffiness, or broken skin.
        Describe the differences first, then rate. \(commonRules)
        """
    static let perception = "You describe what is visible in a photo of skin. Do not give medical advice."
}

extension Rubric {
    /// The relative2 guidance applied to absolute rubric levels, for rating one photo without a reference.
    var absoluteInstructions: String {
        var text = """
            You rate a photo of skin for visible signs of eczema using the rubric below. Signs are \
            often 0. Give a level above 0 only if you can see a specific spot that matches its \
            definition. Describe what you see first, then score each sign from 0 to 3. List the id \
            of a sign you cannot judge in unscorableSigns and give it 0. \(scoring) \(commonRules)

            """
        for sign in signs {
            text += "\n\(sign.id) (\(sign.name)):"
            if let lookFor = sign.lookFor { text += " \(lookFor)" }
            for level in ["0", "1", "2", "3"] { text += "\n  \(level) = \(sign.levels[level] ?? "")" }
        }
        return text
    }
}

extension Rubric {
    private var dryness: Sign { signs.first { $0.id == "dryness-flaking" }! }
    private var drynessLevels: String {
        ["0", "1", "2", "3"].map { "\($0) = \(dryness.levels[$0] ?? "")" }.joined(separator: "\n")
    }

    var drynessInstructions: String {
        """
        You rate dryness of the skin in a photo. Look for: \(dryness.lookFor ?? "") \(scoring) Describe any \
        flakes or scales first, then choose a level. If the image shows no skin, choose 0.
        \(drynessLevels)
        \(commonRules)
        """
    }

    var drynessRelativeInstructions: String {
        """
        You compare dryness in a new photo of one person's skin with a reference photo of their clear skin. \
        Look for: \(dryness.lookFor ?? "") The new photo is often the same as the reference. Answer same \
        unless some patch in the new photo clearly shows more flakes or scales than the reference, then say \
        slightly more, clearly more, or much more. Describe the flakes first. \(commonRules)
        """
    }

    /// Instructions for rating one sign alone on its rubric levels.
    func signOnlyInstructions(_ id: String) -> String {
        let sign = signs.first { $0.id == id }!
        return """
            You rate one sign of eczema, \(sign.name.lowercased()), in a photo of skin.\(sign.lookFor.map { " Look for: \($0)" } ?? "") \
            \(scoring) Describe what you see first, then choose a level.
            \(["0", "1", "2", "3"].map { "\($0) = \(sign.levels[$0] ?? "")" }.joined(separator: "\n"))
            \(commonRules)
            """
    }

    private var swelling: Sign { signs.first { $0.id == "swelling" }! }

    var swellingRubricInstructions: String {
        """
        You compare swelling in a new photo of one person's skin with a reference photo of the same area \
        on a clear day. Look for: \(swelling.lookFor ?? "") Describe where the new photo looks puffier \
        than the reference, then choose a level; choose 0 if it is no puffier than the reference.
        \(["0", "1", "2", "3"].map { "\($0) = \(swelling.levels[$0] ?? "")" }.joined(separator: "\n"))
        Ignore expression, angle, lighting, makeup, hair, and background. Do not give medical advice.
        """
    }

    var swellingCueInstructions: String {
        """
        You compare the shape and surface of one person's skin in a new photo with a reference photo of \
        the same area on a clear day. Swelling is \(swelling.lookFor ?? "") Describe the differences, then \
        answer each question about the new photo compared with the reference. Ignore expression, angle, \
        lighting, makeup, hair, and background. Do not give medical advice.
        """
    }

    var swellingPairInstructions: String {
        """
        You compare swelling in two photos of the same area of one person's skin. Swelling is \
        \(swelling.lookFor ?? "") Describe how the puffiness differs, then say which photo shows more \
        swelling. Answer same unless one is clearly puffier. Ignore expression, angle, lighting, makeup, \
        hair, and background. Do not give medical advice.
        """
    }

    var flakeCheckInstructions: String {
        """
        You look for flakes and scales on the skin in a photo. Look for: \(dryness.lookFor ?? "") Describe \
        what you see first, then say whether you see none, a few, or many. \(commonRules)
        """
    }
}

extension Rater {
    func ask<T: Generable>(_ type: T.Type, instructions: String, prompt: Prompt) async -> (T?, Double, String?) {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let session = LanguageModelSession(instructions: instructions)
            let options = greedy ? GenerationOptions(sampling: .greedy) : GenerationOptions()
            let response = try await session.respond(to: prompt, generating: type, options: options)
            return (response.content, seconds(since: start, clock), nil)
        } catch {
            return (nil, seconds(since: start, clock), Failure.classify(error))
        }
    }

    func ratePrompt(photo: URL) -> Prompt {
        Prompt {
            "Rate the skin in this photo using the rubric."
            Attachment(imageURL: photo)
        }
    }

    func describePrompt(photo: URL) -> Prompt {
        Prompt {
            "Describe the skin in this photo."
            Attachment(imageURL: photo)
        }
    }

    func anchoredPrompt(reference: URL, photo: URL, referenceFirst: Bool, noun: String = "photo") -> Prompt {
        Prompt {
            if referenceFirst {
                "Reference photo of clear skin, rated 0:"
                Attachment(imageURL: reference)
                "New \(noun) to rate:"
                Attachment(imageURL: photo)
            } else {
                "New \(noun) to rate:"
                Attachment(imageURL: photo)
                "Reference photo of clear skin, rated 0:"
                Attachment(imageURL: reference)
            }
            "Rate the new \(noun)."
        }
    }
}

/// Splits an image into a 2 by 2 grid of JPEG tiles in the temporary folder.
func quadrantTiles(of url: URL) -> [URL] {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [] }
    let w = image.width / 2, h = image.height / 2
    var urls: [URL] = []
    for (i, origin) in [(0, 0), (w, 0), (0, h), (w, h)].enumerated() {
        guard let tile = image.cropping(to: CGRect(x: origin.0, y: origin.1, width: w, height: h)) else { continue }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-tile\(i).jpg")
        guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { continue }
        CGImageDestinationAddImage(dest, tile, nil)
        if CGImageDestinationFinalize(dest) { urls.append(out) }
    }
    return urls
}

/// Writes a copy of the image with saturation and contrast raised, so redness stands out more.
/// Apply it to the reference and the photo alike so the comparison stays fair.
func boosted(_ url: URL) -> URL {
    if CommandLine.arguments.contains("-noboost") { return url }
    let out = FileManager.default.temporaryDirectory.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-boost.jpg")
    guard let input = CIImage(contentsOf: url),
          let filter = CIFilter(name: "CIColorControls") else { return url }
    filter.setValue(input, forKey: kCIInputImageKey)
    filter.setValue(2.0, forKey: kCIInputSaturationKey)
    filter.setValue(1.15, forKey: kCIInputContrastKey)
    let context = CIContext()
    guard let output = filter.outputImage,
          let space = CGColorSpace(name: CGColorSpace.sRGB),
          (try? context.writeJPEGRepresentation(of: output, to: out, colorSpace: space)) != nil else { return url }
    return out
}

/// Writes a crop of the eyes, eyebrows, and the skin under the eyes, found by face landmarks.
/// Returns nil when no face is found.
func eyeRegion(of url: URL) -> URL? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let request = VNDetectFaceLandmarksRequest()
    try? VNImageRequestHandler(cgImage: image).perform([request])
    guard let landmarks = request.results?.first?.landmarks else { return nil }
    let size = CGSize(width: image.width, height: image.height)
    let points = [landmarks.leftEye, landmarks.rightEye, landmarks.leftEyebrow, landmarks.rightEyebrow]
        .compactMap { $0?.pointsInImage(imageSize: size) }.flatMap { $0 }
    guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
          let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return nil }
    // Vision points have a bottom-left origin; the crop rectangle uses a top-left origin.
    let width = maxX - minX, height = maxY - minY
    let rect = CGRect(x: minX - 0.15 * width, y: size.height - maxY - 0.3 * height, width: width * 1.3, height: height * 2.3)
        .intersection(CGRect(origin: .zero, size: size))
    guard let crop = image.cropping(to: rect) else { return nil }
    let out = FileManager.default.temporaryDirectory.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-eyes.jpg")
    guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(dest, crop, nil)
    return CGImageDestinationFinalize(dest) ? out : nil
}

/// Writes a copy of the image sharpened with more local contrast, so fine light flakes stand out.
func detailed(_ url: URL) -> URL {
    let out = FileManager.default.temporaryDirectory.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-detail.jpg")
    guard let input = CIImage(contentsOf: url),
          let sharpen = CIFilter(name: "CIUnsharpMask"), let controls = CIFilter(name: "CIColorControls") else { return url }
    sharpen.setValue(input, forKey: kCIInputImageKey)
    sharpen.setValue(3.0, forKey: kCIInputRadiusKey)
    sharpen.setValue(1.0, forKey: kCIInputIntensityKey)
    controls.setValue(sharpen.outputImage, forKey: kCIInputImageKey)
    controls.setValue(1.2, forKey: kCIInputContrastKey)
    let context = CIContext()
    guard let output = controls.outputImage?.cropped(to: input.extent),
          let space = CGColorSpace(name: CGColorSpace.sRGB),
          (try? context.writeJPEGRepresentation(of: output, to: out, colorSpace: space)) != nil else { return url }
    return out
}

/// Returns eye opening as the mean height-to-width ratio of both eye outlines, or nil without a face.
func eyeOpening(of url: URL) -> Double? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let request = VNDetectFaceLandmarksRequest()
    try? VNImageRequestHandler(cgImage: image).perform([request])
    guard let landmarks = request.results?.first?.landmarks else { return nil }
    let size = CGSize(width: image.width, height: image.height)
    let ratios = [landmarks.leftEye, landmarks.rightEye].compactMap { region -> Double? in
        guard let points = region?.pointsInImage(imageSize: size),
              let x0 = points.map(\.x).min(), let x1 = points.map(\.x).max(),
              let y0 = points.map(\.y).min(), let y1 = points.map(\.y).max(), x1 > x0 else { return nil }
        return Double((y1 - y0) / (x1 - x0))
    }
    return ratios.isEmpty ? nil : ratios.reduce(0, +) / Double(ratios.count)
}

/// Maps the drop in eye opening against the reference photo to a swelling level. Provisional
/// thresholds, set from a single flare photo.
func swellingLevel(opening: Double, referenceOpening: Double) -> Int {
    let drop = 1 - opening / referenceOpening
    switch drop {
    case ..<0.08: return 0
    case ..<0.15: return 1
    case ..<0.22: return 2
    default: return 3
    }
}

struct FlakeDensity {
    let specks: Int
    let perMegapixel: Double
    let areaPermille: Double
}

/// Measures flake-like specks: small areas brighter and less saturated than the skin around them.
/// Window size and speck size scale with image width so crops at different sizes are comparable.
/// Returns nil when the image cannot be read.
func flakeDensity(of url: URL) -> FlakeDensity? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    let w = image.width, h = image.height
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    guard let context = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

    var luma = [Double](repeating: 0, count: w * h)
    var saturation = [Double](repeating: 0, count: w * h)
    for i in 0..<(w * h) {
        let r = Double(pixels[i * 4]), g = Double(pixels[i * 4 + 1]), b = Double(pixels[i * 4 + 2])
        luma[i] = 0.299 * r + 0.587 * g + 0.114 * b
        let high = max(r, g, b), low = min(r, g, b)
        saturation[i] = high > 0 ? (high - low) / high : 0
    }
    func integral(_ values: [Double]) -> [Double] {
        var sums = [Double](repeating: 0, count: (w + 1) * (h + 1))
        for y in 0..<h {
            var row = 0.0
            for x in 0..<w {
                row += values[y * w + x]
                sums[(y + 1) * (w + 1) + x + 1] = sums[y * (w + 1) + x + 1] + row
            }
        }
        return sums
    }
    let lumaSums = integral(luma), saturationSums = integral(saturation)
    let scale = Double(w) / 657
    let radius = max(6, Int(14 * scale))
    func boxMean(_ sums: [Double], _ x: Int, _ y: Int) -> Double {
        let x0 = max(0, x - radius), x1 = min(w, x + radius + 1), y0 = max(0, y - radius), y1 = min(h, y + radius + 1)
        let total = sums[y1 * (w + 1) + x1] - sums[y0 * (w + 1) + x1] - sums[y1 * (w + 1) + x0] + sums[y0 * (w + 1) + x0]
        return total / Double((x1 - x0) * (y1 - y0))
    }
    var bright = [Bool](repeating: false, count: w * h)
    for y in 0..<h {
        for x in 0..<w {
            let i = y * w + x
            if luma[i] > 110, luma[i] - boxMean(lumaSums, x, y) > 16, saturation[i] < boxMean(saturationSums, x, y) - 0.03 {
                bright[i] = true
            }
        }
    }
    let smallest = Int(4 * scale * scale), largest = Int(260 * scale * scale)
    var visited = [Bool](repeating: false, count: w * h)
    var specks = 0, speckArea = 0
    for start in 0..<(w * h) where bright[start] && !visited[start] {
        var stack = [start], area = 0
        visited[start] = true
        while let p = stack.popLast() {
            area += 1
            let x = p % w, y = p / w
            for dy in -1...1 {
                for dx in -1...1 {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < w, ny >= 0, ny < h, bright[ny * w + nx], !visited[ny * w + nx] else { continue }
                    visited[ny * w + nx] = true
                    stack.append(ny * w + nx)
                }
            }
        }
        if area >= smallest && area <= largest { specks += 1; speckArea += area }
    }
    let megapixels = Double(w * h) / 1e6
    return FlakeDensity(specks: specks, perMegapixel: Double(specks) / megapixels, areaPermille: 1000 * Double(speckArea) / Double(w * h))
}

/// Writes a downscaled copy of the image whose longest side is at most `maxSide` pixels.
func resized(_ url: URL, maxSide: Int) -> URL {
    let out = FileManager.default.temporaryDirectory.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-\(maxSide).jpg")
    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                    kCGImageSourceThumbnailMaxPixelSize: maxSide,
                                    kCGImageSourceCreateThumbnailWithTransform: true]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
          let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return url }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest) ? out : url
}
