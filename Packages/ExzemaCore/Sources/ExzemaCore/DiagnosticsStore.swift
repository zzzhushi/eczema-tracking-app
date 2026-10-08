import Foundation

/// The kinds of report the system delivers; each report has exactly one. A kind the app does not recognize is kept as `unknown`.
public enum DiagnosticKind: String, CaseIterable, Sendable {
    case crash
    case hang
    case cpuException
    case diskWriteException
    case appLaunch
    case memoryException
    case unknown
}

public struct SavedDiagnostic: Equatable, Sendable {
    public let url: URL
    public let kind: DiagnosticKind
    public let receivedAt: Date
}

/// Keeps crash and hang reports as local JSON files that are never backed up and never sent anywhere.
///
/// Reports hold call stacks and device details, not health data; they are read by pulling the app container.
public struct DiagnosticsStore: Sendable {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// Write `report` as received at `receivedAt`; reports received at the same instant are all kept.
    @discardableResult
    public func save(_ report: Data, kind: DiagnosticKind, receivedAt: Date) throws -> SavedDiagnostic {
        try ensureDirectory()
        let stamp = receivedAt.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false).timeSeparator(.omitted).dateSeparator(.omitted))
        let url = directory.appendingPathComponent("\(kind.rawValue)-\(stamp)-\(UUID().uuidString.prefix(8)).json")
        try report.write(to: url, options: .atomic)
        try Self.excludeFromBackup(url)
        return SavedDiagnostic(url: url, kind: kind, receivedAt: receivedAt)
    }

    /// Return every saved report, newest first.
    public func reports() throws -> [SavedDiagnostic] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return urls.compactMap(Self.parse).sorted { $0.receivedAt > $1.receivedAt }
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.excludeFromBackup(directory)
    }

    private static func parse(_ url: URL) -> SavedDiagnostic? {
        let parts = url.deletingPathExtension().lastPathComponent.split(separator: "-")
        guard parts.count == 3, let kind = DiagnosticKind(rawValue: String(parts[0])),
              let receivedAt = try? Date(String(parts[1]), strategy: stampStrategy)
        else { return nil }
        return SavedDiagnostic(url: url, kind: kind, receivedAt: receivedAt)
    }

    private static let stampStrategy = Date.ISO8601FormatStyle(timeZone: .gmt)
        .year().month().day().time(includingFractionalSeconds: false).timeSeparator(.omitted).dateSeparator(.omitted)

    private static func excludeFromBackup(_ url: URL) throws {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
}
