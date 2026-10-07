/// The feature a log line belongs to; one unified-log category per case.
public enum LogCategory: String, CaseIterable, Sendable {
    case app
    case storage
    case foodLogging
    case checkIn
    case photos
    case analysis
    case diagnostics
}

/// Unified-log levels. Notice and above persist on the phone; debug and info are live only.
public enum LogLevel: Sendable {
    case debug, info, notice, error, fault
}

/// A value that is safe to log in the clear: a number, a flag, or fixed text written in source.
///
/// There is no conversion from a dynamic string, so user text cannot reach a public field.
public enum PublicLogValue: Hashable, Sendable,
    ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral, ExpressibleByStringLiteral
{
    case int(Int)
    case bool(Bool)
    case text(String)

    public init(integerLiteral value: Int) { self = .int(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(stringLiteral value: StaticString) { self = .text("\(value)") }

    public typealias StringLiteralType = StaticString

    var rendered: String {
        switch self {
        case .int(let value): String(value)
        case .bool(let value): String(value)
        case .text(let value): value
        }
    }
}

/// One log event, with public and private fields kept apart until the sink writes them.
public struct LogRecord: Equatable, Sendable {
    public let category: LogCategory
    public let level: LogLevel
    public let event: String
    public let publicFields: [String: PublicLogValue]
    public let privateFields: [String: String]

    public init(
        category: LogCategory,
        level: LogLevel,
        event: String,
        publicFields: [String: PublicLogValue],
        privateFields: [String: String]
    ) {
        self.category = category
        self.level = level
        self.event = event
        self.publicFields = publicFields
        self.privateFields = privateFields
    }
}

public protocol LogSink: Sendable {
    func write(_ record: LogRecord)
}

/// Logs events for one category. Fields are private unless passed as `public`.
///
/// An event is a fixed, searchable name such as `store.opened`; data goes in fields, never in the name.
public struct CategoryLogger: Sendable {
    public let category: LogCategory
    private let sink: any LogSink

    public init(_ category: LogCategory, sink: any LogSink = OSLogSink()) {
        self.category = category
        self.sink = sink
    }

    public func debug(_ event: String, public publicFields: [String: PublicLogValue] = [:], private privateFields: [String: String] = [:]) {
        write(.debug, event, publicFields, privateFields)
    }

    public func info(_ event: String, public publicFields: [String: PublicLogValue] = [:], private privateFields: [String: String] = [:]) {
        write(.info, event, publicFields, privateFields)
    }

    public func notice(_ event: String, public publicFields: [String: PublicLogValue] = [:], private privateFields: [String: String] = [:]) {
        write(.notice, event, publicFields, privateFields)
    }

    public func error(_ event: String, public publicFields: [String: PublicLogValue] = [:], private privateFields: [String: String] = [:]) {
        write(.error, event, publicFields, privateFields)
    }

    public func fault(_ event: String, public publicFields: [String: PublicLogValue] = [:], private privateFields: [String: String] = [:]) {
        write(.fault, event, publicFields, privateFields)
    }

    private func write(
        _ level: LogLevel,
        _ event: String,
        _ publicFields: [String: PublicLogValue],
        _ privateFields: [String: String]
    ) {
        sink.write(LogRecord(
            category: category, level: level, event: event,
            publicFields: publicFields, privateFields: privateFields
        ))
    }
}

/// The loggers features use, one per category.
public enum Log {
    public static let app = CategoryLogger(.app)
    public static let storage = CategoryLogger(.storage)
    public static let foodLogging = CategoryLogger(.foodLogging)
    public static let checkIn = CategoryLogger(.checkIn)
    public static let photos = CategoryLogger(.photos)
    public static let analysis = CategoryLogger(.analysis)
    public static let diagnostics = CategoryLogger(.diagnostics)
}
