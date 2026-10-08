import Foundation
import Testing
@testable import ExzemaCore

@Suite("File log sink")
struct FileLogSinkTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FileLogSinkTests-\(UUID().uuidString)", isDirectory: true)

    private func record(
        _ level: LogLevel, _ event: LogEvent, public publicFields: [LogKey: PublicLogValue] = [:], private privateFields: [LogKey: String] = [:]
    ) -> LogRecord {
        LogRecord(category: .foodLogging, level: level, event: event, publicFields: publicFields, privateFields: privateFields)
    }

    private func lines(_ name: String) throws -> [[String: Any]] {
        let url = directory.appendingPathComponent(name)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return try text.split(separator: "\n").map { try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any]) }
    }

    private func text(_ name: String) -> String {
        (try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)) ?? ""
    }

    @Test func eachNoticeErrorAndFaultIsOneJSONLine() throws {
        let sink = try FileLogSink(directory: directory, clock: { Date(timeIntervalSince1970: 1_791_492_000) })

        sink.write(record(.notice, "foodLine.added", public: ["items": 3, "retried": false, "reason": "modelUnavailable"]))
        sink.write(record(.error, "foodLine.saveFailed"))
        sink.write(record(.fault, "store.unavailable"))

        let written = try lines("current.jsonl")
        #expect(written.map { $0["event"] as? String } == ["foodLine.added", "foodLine.saveFailed", "store.unavailable"])
        #expect(written.map { $0["level"] as? String } == ["notice", "error", "fault"])
        #expect(written[0]["category"] as? String == "foodLogging")
        #expect(written[0]["time"] as? String == "2026-10-08T20:40:00.000Z")
        #expect(written[0]["fields"] as? [String: String] == ["items": "3", "retried": "false", "reason": "modelUnavailable"])
    }

    @Test func debugAndInfoAreNotKept() throws {
        let sink = try FileLogSink(directory: directory)

        sink.write(record(.debug, "a"))
        sink.write(record(.info, "b"))
        sink.write(record(.notice, "c"))

        #expect(try lines("current.jsonl").map { $0["event"] as? String } == ["c"])
    }

    @Test func privateValuesNeverReachTheFileButTheirNamesDo() throws {
        let sink = try FileLogSink(directory: directory)

        sink.write(record(.error, "checkin.saveFailed", private: ["feel": "SECRET-7", "date": "SECRET-2026-10-08"]))

        let all = text("current.jsonl")
        #expect(!all.contains("SECRET"), "a private value must never be written to the file")
        #expect(try lines("current.jsonl")[0]["privateKeys"] as? [String] == ["date", "feel"])
    }

    @Test func aFullFileIsKeptAsThePreviousOneAndAFreshOneStarts() throws {
        let sink = try FileLogSink(directory: directory, maxFileBytes: 600)

        for number in 0..<30 { sink.write(record(.notice, "event", public: ["n": .int(number)])) }

        let previous = try lines("previous.jsonl").compactMap(number)
        let current = try lines("current.jsonl").compactMap(number)
        #expect(!previous.isEmpty && !current.isEmpty)
        #expect(current.last == 29, "the newest record must be in the current file")
        #expect((previous.last ?? 0) < (current.first ?? 0), "the previous file must hold records older than the current one")
        let bytes = ["current.jsonl", "previous.jsonl"].map { (try? Data(contentsOf: directory.appendingPathComponent($0)).count) ?? 0 }
        #expect(bytes.allSatisfy { $0 <= 600 }, "each file must stay within its cap")
    }

    @Test func theFolderIsCreatedAndExcludedFromBackup() throws {
        _ = try FileLogSink(directory: directory.appendingPathComponent("nested/Logs"))

        let values = try directory.appendingPathComponent("nested/Logs").resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test func recordsFromManyThreadsAreAllKeptAsWholeLines() throws {
        let sink = try FileLogSink(directory: directory)

        DispatchQueue.concurrentPerform(iterations: 50) { n in sink.write(record(.notice, "event", public: ["n": .int(n)])) }

        let numbers = try lines("current.jsonl").compactMap(number)
        #expect(Set(numbers) == Set(0..<50) && numbers.count == 50)
    }

    private func number(_ line: [String: Any]) -> Int? {
        (line["fields"] as? [String: String])?["n"].flatMap(Int.init)
    }
}

@Suite("Log files", .serialized)
struct LogFilesTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LogFilesTests-\(UUID().uuidString)", isDirectory: true)

    private func events() -> [String] {
        guard let text = try? String(contentsOf: directory.appendingPathComponent("current.jsonl"), encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap {
            (try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])?["event"] as? String
        }
    }

    @Test func nothingIsWrittenUntilFileLoggingIsEnabled() {
        LogFiles.disable()

        CategoryLogger(.app).notice("files.test.before")

        #expect(events().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func theStandardLoggerWritesToTheFileOnceEnabledAndStopsWhenDisabled() throws {
        try LogFiles.enable(directory: directory)
        defer { LogFiles.disable() }

        CategoryLogger(.app).notice("files.test.enabled")
        #expect(events().contains("files.test.enabled"))

        LogFiles.disable()
        CategoryLogger(.app).notice("files.test.disabled")
        #expect(!events().contains("files.test.disabled"))
    }
}
