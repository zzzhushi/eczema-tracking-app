import Foundation
import OSLog
import Testing
import ExzemaCore

/// Reads the process's own unified-log entries back to check what Apple's logging actually redacts.
///
/// Redaction is lifted while a debugger is attached, so these checks run only without one.
@Suite("Unified log redaction", .enabled(if: !isDebuggerAttached()))
struct OSLogRedactionTests {
    @Test func privateFieldValuesAreRedactedWhileTheirNamesStayVisible() async throws {
        let event = "rating.saved.\(UUID().uuidString.prefix(8))"
        let secret = "secret-\(UUID().uuidString.prefix(8))"
        let log = CategoryLogger(.checkIn, sink: OSLogSink())

        log.notice(event, public: ["schemaVersion": 1], private: ["feel": "7", "note": secret])

        let message = try await composedMessage(containing: event)
        #expect(message == "\(event) schemaVersion=1 private=[feel,note] <private>")
        #expect(!message.contains(secret), "a private value leaked into the unified log")
        #expect(!message.contains("feel=7"), "a numeric private value leaked into the unified log")
    }

    @Test func eventWithoutPrivateFieldsShowsNoPrivatePlaceholder() async throws {
        let event = "store.probe.\(UUID().uuidString.prefix(8))"
        let log = CategoryLogger(.storage, sink: OSLogSink())

        log.notice(event, public: ["schemaVersion": 1, "count": 3])

        #expect(try await composedMessage(containing: event) == "\(event) count=3 schemaVersion=1")
    }

    @Test func eventWithNoFieldsIsJustItsName() async throws {
        let event = "app.probe.\(UUID().uuidString.prefix(8))"

        CategoryLogger(.app, sink: OSLogSink()).notice(event)

        #expect(try await composedMessage(containing: event) == event)
    }

    private func composedMessage(containing text: String) async throws -> String {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        for _ in 0..<40 {
            let entries = try store.getEntries(at: store.position(timeIntervalSinceEnd: -30))
            let match = entries.compactMap { $0 as? OSLogEntryLog }
                .last { $0.subsystem == OSLogSink.subsystem && $0.composedMessage.contains(text) }
            if let match { return match.composedMessage }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("the log entry never appeared in the process's log store")
        return ""
    }
}

private func isDebuggerAttached() -> Bool {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else { return false }
    return (info.kp_proc.p_flag & P_TRACED) != 0
}
