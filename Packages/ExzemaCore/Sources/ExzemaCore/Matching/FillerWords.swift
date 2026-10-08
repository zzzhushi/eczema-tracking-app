import Foundation

/// Words typed between foods that are neither a food nor worth keeping as an unrecognized entry.
public enum FillerWords {
    private struct File: Decodable {
        var words: [String]
    }

    /// Reads `catalog/filler-words.json` beneath `dataDirectory`.
    public static func load(dataDirectory: URL) throws -> Set<String> {
        let url = dataDirectory.appending(path: "catalog/filler-words.json")
        return Set(try JSONDecoder().decode(File.self, from: Data(contentsOf: url)).words)
    }
}
