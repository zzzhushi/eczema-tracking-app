import Foundation
import OSLog
import Testing
import ExzemaCore

/// Reads the process's own unified-log entries back to check what Apple's logging actually redacts.
///
/// Redaction is lifted while a debugger is attached, so these checks run only without one.
@Suite("Unified log redaction", .enabled(if: !isDebuggerAttached()))
struct OSLogRedactionTests {
    @Test func privateFieldsAreRedactedAndPublicFieldsAreNot() async throws {
        let marker = "marker-\(UUID().uuidString.prefix(8))"
        let log = CategoryLogger(.checkIn, sink: OSLogSink())

        log.notice("rating.saved", public: ["schemaVersion": 1], private: ["feel": "7", "note": marker])

        let message = try await composedMessage(containing: "rating.saved")
        #expect(message.contains("schemaVersion=1"))
        #expect(message.contains("<private>"))
        #expect(!message.contains(marker), "a private field leaked into the unified log")
        #expect(!message.contains("feel=7"), "a numeric private field leaked into the unified log")
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
