import Foundation

/// One piece of typed text and what it resolved to.
public struct ParsedItem: Equatable, Sendable {
    public enum Resolution: Equatable, Sendable {
        case matched(foodID: String)
        case unrecognized
    }

    /// The words as typed, with their original spelling, joined by single spaces.
    public var text: String
    public var resolution: Resolution

    public init(text: String, resolution: Resolution) {
        self.text = text
        self.resolution = resolution
    }
}

/// Splits typed food text into items and matches each to a catalog food by alias.
///
/// Parsing is a pure function of the text, the catalog's aliases, and the filler words: the same inputs
/// always give the same items. Nothing in the text is dropped except filler words and punctuation, so a word
/// that names no food surfaces as an unrecognized item.
public struct FoodMatcher: Sendable {
    private struct Token {
        var original: String
        var key: String
    }

    private let foodIDsByAlias: [String: String]
    private let longestAliasInWords: Int
    private let fillerWords: Set<String>
    private let signposter: Signposter

    /// Aliases must be unique across `foods`; `Catalog.validate()` guarantees it for the shipped catalog.
    public init(foods: [Food], fillerWords: Set<String>, signposter: Signposter = Signpost.shared) {
        var index: [String: String] = [:]
        var longest = 1
        for food in foods {
            for alias in food.aliases {
                let words = Self.tokenize(alias).compactMap { $0?.key }
                guard !words.isEmpty else { continue }
                index[words.joined(separator: " ")] = food.id
                longest = max(longest, words.count)
            }
        }
        self.foodIDsByAlias = index
        self.longestAliasInWords = longest
        self.fillerWords = fillerWords
        self.signposter = signposter
    }

    /// Returns the items in typed order. A piece of text with no words returns no items.
    ///
    /// The longest alias at each position wins, so "chicken thigh" is not read as "chicken". Punctuation,
    /// newlines, filler words, and matches end a run of unmatched words; each run is one unrecognized item.
    public func parse(_ text: String) -> [ParsedItem] {
        signposter.interval(.mealParsing) {
            let tokens = Self.tokenize(text)
            var items: [ParsedItem] = []
            var run: [Token] = []

            func endRun() {
                guard !run.isEmpty else { return }
                items.append(ParsedItem(text: run.map(\.original).joined(separator: " "), resolution: .unrecognized))
                run = []
            }

            var position = 0
            while position < tokens.count {
                guard let token = tokens[position] else {
                    endRun()
                    position += 1
                    continue
                }
                if let (length, foodID) = longestAlias(startingAt: position, in: tokens) {
                    endRun()
                    let typed = tokens[position..<position + length].compactMap { $0?.original }.joined(separator: " ")
                    items.append(ParsedItem(text: typed, resolution: .matched(foodID: foodID)))
                    position += length
                    continue
                }
                if fillerWords.contains(token.key) {
                    endRun()
                } else {
                    run.append(token)
                }
                position += 1
            }
            endRun()
            return items
        }
    }

    private func longestAlias(startingAt start: Int, in tokens: [Token?]) -> (length: Int, foodID: String)? {
        let available = min(longestAliasInWords, tokens.count - start)
        guard available >= 1 else { return nil }
        for length in stride(from: available, through: 1, by: -1) {
            let words = tokens[start..<start + length].compactMap { $0?.key }
            guard words.count == length else { continue }
            if let foodID = foodIDsByAlias[words.joined(separator: " ")] { return (length, foodID) }
        }
        return nil
    }

    /// Words are runs of letters, digits, hyphens, and apostrophes; `nil` marks punctuation or a newline.
    private static func tokenize(_ text: String) -> [Token?] {
        var tokens: [Token?] = []
        var word = ""

        func endWord() {
            defer { word = "" }
            guard !word.isEmpty else { return }
            if word.contains(where: { $0.isLetter || $0.isNumber }) {
                tokens.append(Token(original: word, key: word.lowercased()))
            } else {
                tokens.append(nil)
            }
        }

        for character in text {
            if character.isLetter || character.isNumber || character == "-" || character == "'" || character == "\u{2019}" {
                word.append(character)
            } else if character.isNewline || !character.isWhitespace {
                endWord()
                tokens.append(nil)
            } else {
                endWord()
            }
        }
        endWord()
        return tokens
    }
}
