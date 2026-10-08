import os

/// Writes records to Apple's unified log: public fields in the clear, private field names in the clear, private values redacted.
public struct OSLogSink: LogSink {
    public static let subsystem = "com.zzzhushi.exzema"

    public init() {}

    public func write(_ record: LogRecord) {
        let logger = os.Logger(subsystem: Self.subsystem, category: record.category.rawValue)

        var head = [record.event.name]
        head += record.publicFields.sorted { $0.key.name < $1.key.name }.map { "\($0.key.name)=\($0.value.rendered)" }
        let privateKeys = record.privateFields.keys.map(\.name).sorted()
        if !privateKeys.isEmpty {
            head.append("private=[\(privateKeys.joined(separator: ","))]")
        }
        let headText = head.joined(separator: " ")

        if privateKeys.isEmpty {
            logger.log(level: record.level.osLogType, "\(headText, privacy: .public)")
        } else {
            let values = record.privateFields.sorted { $0.key.name < $1.key.name }.map { "\($0.key.name)=\($0.value)" }.joined(separator: " ")
            logger.log(level: record.level.osLogType, "\(headText, privacy: .public) \(values, privacy: .private)")
        }
    }
}

private extension LogLevel {
    var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .notice: .default
        case .error: .error
        case .fault: .fault
        }
    }
}
