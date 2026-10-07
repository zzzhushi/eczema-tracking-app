import FoundationModels
import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreImage

/// Experiment variants that rate a photo relative to a reference photo of the same person's clear skin.
enum Variant: String, CaseIterable {
    case overall3, checklist, relative, tiles, perception, relative2, direct3, identical, relative2Boost, rednessBoost, relative2Sampled, relative2BoostSampled
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

@Generable
struct RednessOnly {
    @Guide(description: "How the redness of the new photo differs from the reference, in one sentence")
    var differences: String
    @Guide(description: "Redness compared with the reference", .anyOf(["same", "slightly more", "clearly more", "much more"]))
    var redness: String

    var level: Int { relativeLevels.firstIndex(of: redness) ?? -1 }
}

enum AnchoredPrompts {
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
