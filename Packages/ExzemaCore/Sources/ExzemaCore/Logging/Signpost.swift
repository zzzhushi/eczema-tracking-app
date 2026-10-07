/// The timed operations Instruments shows; a fixed list so every feature names them the same way.
public enum SignpostInterval: String, CaseIterable, Sendable {
    case mealParsing
    case photoRating
    case analysis
}

public struct SignpostToken: Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public protocol SignpostSink: Sendable {
    func begin(_ interval: SignpostInterval) -> SignpostToken
    func end(_ interval: SignpostInterval, token: SignpostToken)
}

/// Brackets an operation with a begin and an end signpost, ending it even when the body throws.
public struct Signposter: Sendable {
    private let sink: any SignpostSink

    public init(sink: any SignpostSink = OSSignpostSink()) {
        self.sink = sink
    }

    public func interval<Result>(_ interval: SignpostInterval, _ body: () throws -> Result) rethrows -> Result {
        let token = sink.begin(interval)
        defer { sink.end(interval, token: token) }
        return try body()
    }

    public func interval<Result>(_ interval: SignpostInterval, _ body: () async throws -> Result) async rethrows -> Result {
        let token = sink.begin(interval)
        defer { sink.end(interval, token: token) }
        return try await body()
    }
}

/// The signposter features use.
public enum Signpost {
    public static let shared = Signposter()
}
