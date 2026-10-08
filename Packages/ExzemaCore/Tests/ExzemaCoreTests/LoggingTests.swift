import Testing
import ExzemaCore

final class RecordingLogSink: LogSink, @unchecked Sendable {
    private(set) var records: [LogRecord] = []
    func write(_ record: LogRecord) { records.append(record) }
}

@Suite("Logging convention")
struct LoggingTests {
    private let sink = RecordingLogSink()

    @Test func eventIsRecordedWithItsCategoryAndLevel() {
        let log = CategoryLogger(.storage, sink: sink)

        log.notice("store.opened")

        #expect(sink.records == [
            LogRecord(category: .storage, level: .notice, event: "store.opened", publicFields: [:], privateFields: [:]),
        ])
    }

    @Test(arguments: [
        (LogLevel.debug, "debug"), (.info, "info"), (.notice, "notice"), (.error, "error"), (.fault, "fault"),
    ])
    func eachLevelMethodRecordsItsLevel(level: LogLevel, name: String) {
        let log = CategoryLogger(.app, sink: sink)

        switch level {
        case .debug: log.debug("event")
        case .info: log.info("event")
        case .notice: log.notice("event")
        case .error: log.error("event")
        case .fault: log.fault("event")
        }

        #expect(sink.records.map(\.level) == [level], "\(name) must map to its own level")
    }

    @Test func publicAndPrivateFieldsAreKeptApart() {
        let log = CategoryLogger(.checkIn, sink: sink)

        log.info("rating.saved", public: ["schemaVersion": 1], private: ["feel": "7"])

        let record = sink.records[0]
        #expect(record.publicFields == ["schemaVersion": .int(1)])
        #expect(record.privateFields == ["feel": "7"])
        #expect(record.publicFields["feel"] == nil, "a private field must never be recorded as public")
    }

    @Test func publicValuesAreLimitedToNumbersFlagsAndFixedText() {
        let count = 4
        let log = CategoryLogger(.foodLogging, sink: sink)

        log.error("fallback", public: ["reason": "modelUnavailable", "entries": .int(count), "retried": false])

        #expect(sink.records[0].publicFields == [
            "reason": .text("modelUnavailable"), "entries": .int(4), "retried": .bool(false),
        ])
    }

    @Test func categoriesAreAFixedList() {
        #expect(Set(LogCategory.allCases.map(\.rawValue)) == [
            "app", "storage", "foodLogging", "checkIn", "photos", "analysis", "diagnostics", "environment",
        ])
    }
}

@Suite("Signposts")
struct SignpostTests {
    final class RecordingSignpostSink: SignpostSink, @unchecked Sendable {
        private(set) var events: [String] = []
        func note(_ event: String) { events.append(event) }
        func begin(_ interval: SignpostInterval) -> SignpostToken {
            events.append("begin \(interval.rawValue)")
            return SignpostToken(rawValue: events.count)
        }
        func end(_ interval: SignpostInterval, token: SignpostToken) {
            events.append("end \(interval.rawValue)")
        }
    }

    private let sink = RecordingSignpostSink()

    @Test func intervalReturnsTheBodysValueBetweenBeginAndEnd() {
        let signposter = Signposter(sink: sink)

        let result = signposter.interval(.mealParsing) { sink.note("body"); return 42 }

        #expect(result == 42)
        #expect(sink.events == ["begin mealParsing", "body", "end mealParsing"])
    }

    @Test func intervalEndsEvenWhenTheBodyThrows() {
        struct Boom: Error {}
        let signposter = Signposter(sink: sink)

        #expect(throws: Boom.self) {
            try signposter.interval(.analysis) { throw Boom() }
        }

        #expect(sink.events == ["begin analysis", "end analysis"])
    }

    @Test func intervalsAreAFixedList() {
        #expect(Set(SignpostInterval.allCases.map(\.rawValue)) == ["mealParsing", "photoRating", "analysis"])
    }
}
