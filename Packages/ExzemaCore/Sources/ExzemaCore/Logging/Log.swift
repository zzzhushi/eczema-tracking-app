/// The feature a log line belongs to; one unified-log category per case.
public enum LogCategory: String, CaseIterable, Sendable {
    case app
    case storage
    case foodLogging
    case checkIn
    case photos
    case analysis
    case diagnostics
    case environment
}

/// Unified-log levels. Notice and above persist on the phone; debug and info are live only.
public enum LogLevel: Sendable {
    case debug, info, notice, error, fault
}

/// Text written in source: an event name or a field name.
///
/// Only a string literal converts to it, so text that comes from the user or from data cannot become an event
/// or a field name, which are always logged in the clear.
public struct LogEvent: Hashable, Sendable, ExpressibleByStringLiteral {
    public typealias StringLiteralType = StaticString

    public let name: String

    public init(stringLiteral value: StaticString) {
        name = "\(value)"
    }
}

/// The name of a log field; literal-only for the same reason as `LogEvent`.
public struct LogKey: Hashable, Sendable, ExpressibleByStringLiteral {
    public typealias StringLiteralType = StaticString

    public let name: String

    public init(stringLiteral value: StaticString) {
        name = "\(value)"
    }
}

/// A value that is safe to log in the clear: a number, a flag, or fixed text written in source.
///
/// There is no way to build one from a dynamic string, so user text cannot reach a public field.
public struct PublicLogValue: Hashable, Sendable,
    ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral, ExpressibleByStringLiteral
{
    public typealias StringLiteralType = StaticString

    private enum Storage: Hashable, Sendable {
        case int(Int)
        case bool(Bool)
        case text(String)
    }

    private let storage: Storage

    private init(_ storage: Storage) {
        self.storage = storage
    }

    public static func int(_ value: Int) -> PublicLogValue { PublicLogValue(.int(value)) }
    public static func bool(_ value: Bool) -> PublicLogValue { PublicLogValue(.bool(value)) }
    public static func text(_ value: StaticString) -> PublicLogValue { PublicLogValue(.text("\(value)")) }

    public init(integerLiteral value: Int) { self.init(.int(value)) }
    public init(booleanLiteral value: Bool) { self.init(.bool(value)) }
    public init(stringLiteral value: StaticString) { self.init(.text("\(value)")) }

    var rendered: String {
        switch storage {
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
    public let event: LogEvent
    public let publicFields: [LogKey: PublicLogValue]
    public let privateFields: [LogKey: String]

    public init(
        category: LogCategory,
        level: LogLevel,
        event: LogEvent,
        publicFields: [LogKey: PublicLogValue],
        privateFields: [LogKey: String]
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
/// An event is a fixed, searchable name such as `store.opened`, and field names are fixed too; data goes in field values, never in names.
public struct CategoryLogger: Sendable {
    public let category: LogCategory
    private let sink: any LogSink

    public init(_ category: LogCategory, sink: any LogSink = OSLogSink()) {
        self.category = category
        self.sink = sink
    }

    public func debug(_ event: LogEvent, public publicFields: [LogKey: PublicLogValue] = [:], private privateFields: [LogKey: String] = [:]) {
        write(.debug, event, publicFields, privateFields)
    }

    public func info(_ event: LogEvent, public publicFields: [LogKey: PublicLogValue] = [:], private privateFields: [LogKey: String] = [:]) {
        write(.info, event, publicFields, privateFields)
    }

    public func notice(_ event: LogEvent, public publicFields: [LogKey: PublicLogValue] = [:], private privateFields: [LogKey: String] = [:]) {
        write(.notice, event, publicFields, privateFields)
    }

    public func error(_ event: LogEvent, public publicFields: [LogKey: PublicLogValue] = [:], private privateFields: [LogKey: String] = [:]) {
        write(.error, event, publicFields, privateFields)
    }

    public func fault(_ event: LogEvent, public publicFields: [LogKey: PublicLogValue] = [:], private privateFields: [LogKey: String] = [:]) {
        write(.fault, event, publicFields, privateFields)
    }

    private func write(
        _ level: LogLevel,
        _ event: LogEvent,
        _ publicFields: [LogKey: PublicLogValue],
        _ privateFields: [LogKey: String]
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
    public static let environment = CategoryLogger(.environment)
}
