import Foundation

/// The catalog and the matcher built from it, loaded together so a matcher never exists without its catalog.
public struct FoodMatching: Sendable {
    public let catalog: Catalog
    public let matcher: FoodMatcher

    /// Loads and validates the catalog and the filler words beneath `dataDirectory`.
    ///
    /// Throws when anything is missing or invalid; there is no empty or partial result to fall back on.
    public static func load(dataDirectory: URL, signposter: Signposter = Signpost.shared) throws -> FoodMatching {
        let catalog = try Catalog.load(dataDirectory: dataDirectory)
        let fillerWords = try FillerWords.load(dataDirectory: dataDirectory)
        return FoodMatching(
            catalog: catalog,
            matcher: FoodMatcher(foods: catalog.foods, fillerWords: fillerWords, signposter: signposter)
        )
    }
}
