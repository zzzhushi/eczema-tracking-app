import Foundation
import Testing

/// Scans production sources for constructs the project forbids outside their one allowed home.
@Suite("Source rules")
struct SourceRulesTests {
    private static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static let repositoryRoot = packageRoot.deletingLastPathComponent().deletingLastPathComponent()

    private static var productionSources: [URL] {
        let roots = [
            packageRoot.appendingPathComponent("Sources"),
            repositoryRoot.appendingPathComponent("App"),
        ]
        return roots.flatMap { root -> [URL] in
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
            return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        }
    }

    private func offenders(matching pattern: String, allowedIn allowed: Set<String> = []) throws -> [String] {
        let expression = try Regex(pattern)
        return try Self.productionSources.compactMap { file in
            guard !allowed.contains(file.lastPathComponent) else { return nil }
            let text = try String(contentsOf: file, encoding: .utf8)
            return text.contains(expression) ? file.lastPathComponent : nil
        }
    }

    @Test func sourceTreeIsFound() {
        #expect(!Self.productionSources.isEmpty, "the scan found no sources, so every rule below would pass vacuously")
    }

    @Test func onlyTheLoggingSinkTalksToAppleLogging() throws {
        let direct = try offenders(
            matching: #"\bLogger\s*\(|\bos_log\b|\bOSLog\b|\bos_signpost\b|\bOSSignposter\b|import\s+os(\.log|\.signpost)?\b"#,
            allowedIn: ["OSLogSink.swift", "OSSignpostSink.swift"]
        )

        #expect(direct.isEmpty, "use the logging wrapper instead of Apple's logger in: \(direct)")
    }

    @Test func coreContainsNoNetworkCode() throws {
        let network = try offenders(matching: #"\bURLSession\b|\bURLRequest\b|\bNWConnection\b|import\s+Network\b|\bCFNetwork\b"#)

        #expect(network.isEmpty, "the app sends nothing off the phone on its own; found network code in: \(network)")
    }
}
