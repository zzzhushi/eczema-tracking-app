import Foundation

/// Keeps notice, error, and fault events in two rotating files, one JSON object per line, so they can be
/// copied off the phone without the system log.
///
/// Private values are never written: a record carries only its public fields and the names of its private
/// ones, which is what the system log shows without a debugger attached. Debug and info events are not kept.
public final class FileLogSink: LogSink, @unchecked Sendable {
    public static let currentFileName = "current.jsonl"
    public static let previousFileName = "previous.jsonl"

    private let directory: URL
    private let maxFileBytes: Int
    private let clock: @Sendable () -> Date
    private let queue = DispatchQueue(label: "exzema.file-log")
    private let timeFormat: ISO8601DateFormatter

    /// Creates `directory` if needed and excludes it from backup. Each file stays within `maxFileBytes`, so the
    /// two together are at most twice that.
    public init(directory: URL, maxFileBytes: Int = 512 * 1024, clock: @escaping @Sendable () -> Date = Date.init) throws {
        self.directory = directory
        self.maxFileBytes = maxFileBytes
        self.clock = clock
        timeFormat = ISO8601DateFormatter()
        timeFormat.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    public func write(_ record: LogRecord) {
        guard let level = record.level.fileName else { return }
        let object: [String: Any] = [
            "time": timeFormat.string(from: clock()),
            "level": level,
            "category": record.category.rawValue,
            "event": record.event.name,
            "fields": Dictionary(uniqueKeysWithValues: record.publicFields.map { ($0.key.name, $0.value.rendered) }),
            "privateKeys": record.privateFields.keys.map(\.name).sorted(),
        ]
        guard var line = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]) else { return }
        line.append(0x0A)
        let durable = record.level == .error || record.level == .fault
        queue.sync { append(line, durable: durable) }
    }

    private func append(_ line: Data, durable: Bool) {
        let current = directory.appendingPathComponent(Self.currentFileName)
        let size = (try? FileManager.default.attributesOfItem(atPath: current.path)[.size] as? Int) ?? 0
        if size + line.count > maxFileBytes, size > 0 {
            let previous = directory.appendingPathComponent(Self.previousFileName)
            try? FileManager.default.removeItem(at: previous)
            try? FileManager.default.moveItem(at: current, to: previous)
        }
        if !FileManager.default.fileExists(atPath: current.path) {
            FileManager.default.createFile(atPath: current.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: current) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: line)
        if durable { try? handle.synchronize() }
    }
}

private extension LogLevel {
    /// The level's name in a file, or nil for levels that are not kept.
    var fileName: String? {
        switch self {
        case .debug, .info: nil
        case .notice: "notice"
        case .error: "error"
        case .fault: "fault"
        }
    }
}
