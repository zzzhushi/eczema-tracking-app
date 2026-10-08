import Foundation

/// The sink features log through: Apple's unified log, and the app's log files once they are enabled.
public struct StandardLogSink: LogSink {
    private let unified = OSLogSink()

    public init() {}

    public func write(_ record: LogRecord) {
        unified.write(record)
        LogFiles.sink?.write(record)
    }
}

/// Switches the app's log files on. They are off until the app enables them, so tests and tools never write any.
public enum LogFiles {
    private static let current = Holder()

    /// Starts keeping notice, error, and fault events in files under `directory`.
    public static func enable(directory: URL) throws {
        current.set(try FileLogSink(directory: directory))
    }

    public static func disable() {
        current.set(nil)
    }

    static var sink: FileLogSink? { current.get() }

    private final class Holder: @unchecked Sendable {
        private let lock = NSLock()
        private var sink: FileLogSink?

        func get() -> FileLogSink? { lock.withLock { sink } }
        func set(_ newValue: FileLogSink?) { lock.withLock { sink = newValue } }
    }
}
