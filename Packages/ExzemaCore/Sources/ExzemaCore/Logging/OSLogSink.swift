import os

/// Writes records to Apple's unified log; public fields in the clear, every private field redacted.
public struct OSLogSink: LogSink {
    public static let subsystem = "com.zzzhushi.exzema"

    public init() {}

    public func write(_ record: LogRecord) {
        let logger = os.Logger(subsystem: Self.subsystem, category: record.category.rawValue)
        let publicText = record.publicFields.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.rendered)" }
            .joined(separator: " ")
        let privateText = record.privateFields.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        switch record.level {
        case .debug:
            logger.debug("\(record.event, privacy: .public) \(publicText, privacy: .public) \(privateText, privacy: .private)")
        case .info:
            logger.info("\(record.event, privacy: .public) \(publicText, privacy: .public) \(privateText, privacy: .private)")
        case .notice:
            logger.notice("\(record.event, privacy: .public) \(publicText, privacy: .public) \(privateText, privacy: .private)")
        case .error:
            logger.error("\(record.event, privacy: .public) \(publicText, privacy: .public) \(privateText, privacy: .private)")
        case .fault:
            logger.fault("\(record.event, privacy: .public) \(publicText, privacy: .public) \(privateText, privacy: .private)")
        }
    }
}
