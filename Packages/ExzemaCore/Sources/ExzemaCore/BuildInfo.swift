import Foundation

/// Identifies the installed build by the `yyyyMMddHHmmss` time (the build machine's local time) the build step compiled into the app.
public struct BuildInfo: Sendable {
    private let stamp: String?

    public init(stamp: String?) {
        let trimmed = stamp?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.stamp = trimmed.flatMap { $0.count == 14 && $0.allSatisfy { $0.isASCII && $0.isNumber } ? $0 : nil }
    }

    public var label: String {
        "Build \(stamp ?? "unknown")"
    }

    /// The stamp as a number, which fits in a log's public fields.
    public var number: Int? {
        stamp.flatMap { Int($0) }
    }
}
