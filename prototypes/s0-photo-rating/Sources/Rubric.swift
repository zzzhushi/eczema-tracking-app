import Foundation

struct Rubric: Decodable {
    struct Sign: Decodable {
        let id: String
        let name: String
        let levels: [String: String]
    }
    let version: Int
    let unscored: String
    let signs: [Sign]

    static func load() throws -> Rubric {
        let url = Bundle.main.url(forResource: "v1", withExtension: "json")!
        return try JSONDecoder().decode(Rubric.self, from: Data(contentsOf: url))
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
