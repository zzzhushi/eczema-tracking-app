import Foundation

struct Rubric: Decodable {
    struct Sign: Decodable {
        let id: String
        let name: String
        var lookFor: String?
        let levels: [String: String]
    }
    let version: Int
    let unscored: String
    let scoring: String
    var signs: [Sign]

    static func load() throws -> Rubric {
        let url = Bundle.main.url(forResource: "v1", withExtension: "json")!
        var rubric = try JSONDecoder().decode(Rubric.self, from: Data(contentsOf: url))
        if CommandLine.arguments.contains("-noPigmentNote"), let i = rubric.signs.firstIndex(where: { $0.id == "redness" }) {
            rubric.signs[i].lookFor = nil
        }
        if CommandLine.arguments.contains("-scalingLookFor"), let i = rubric.signs.firstIndex(where: { $0.id == "dryness-flaking" }) {
            rubric.signs[i].lookFor = "Fine scaling: the surface looks broken into small dull or whitish plates, like a mosaic, with scale edges lifting along the skin lines; or loose white flakes. Skin lines without scale are thickening, not dryness."
        }
        return rubric
    }

    var instructions: String {
        var text = """
        You rate a photo of skin for visible signs of eczema using the rubric below. \
        Score each sign from 0 to 3 using exactly the written level definitions. \
        List the id of any sign that cannot be judged from the photo in unscorableSigns \
        and give it 0 as a placeholder. Do not give medical advice.

        """
        for sign in signs {
            text += "\n\(sign.id) (\(sign.name)):"
            for level in ["0", "1", "2", "3"] { text += "\n  \(level) = \(sign.levels[level] ?? "")" }
        }
        return text
    }
}
