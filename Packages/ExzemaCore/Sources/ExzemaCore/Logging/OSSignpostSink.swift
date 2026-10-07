import os

/// Writes signposts to Apple's unified log under the app's subsystem.
public struct OSSignpostSink: SignpostSink {
    private let signposter = OSSignposter(subsystem: OSLogSink.subsystem, category: "timing")
    private let states = OSAllocatedUnfairLock(initialState: [Int: OSSignpostIntervalState]())
    private let counter = OSAllocatedUnfairLock(initialState: 0)

    public init() {}

    public func begin(_ interval: SignpostInterval) -> SignpostToken {
        let id = counter.withLock { value -> Int in
            value += 1
            return value
        }
        let state = signposter.beginInterval(interval.staticName, id: signposter.makeSignpostID())
        states.withLock { $0[id] = state }
        return SignpostToken(rawValue: id)
    }

    public func end(_ interval: SignpostInterval, token: SignpostToken) {
        guard let state = states.withLock({ $0.removeValue(forKey: token.rawValue) }) else { return }
        signposter.endInterval(interval.staticName, state)
    }
}

private extension SignpostInterval {
    var staticName: StaticString {
        switch self {
        case .mealParsing: "mealParsing"
        case .photoRating: "photoRating"
        case .analysis: "analysis"
        }
    }
}
