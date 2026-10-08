#if DEBUG
import Foundation
import Testing
import ExzemaCore

@Suite("Debug faults")
struct DebugFaultsTests {
    private let sink = RecordingLogSink()

    @Test func hangLogsItsStartBeforeAndItsEndAfterTheBlockingWait() {
        var eventsSeenDuringWait: [String] = []
        var waited: TimeInterval?
        let faults = DebugFaults(
            log: CategoryLogger(.diagnostics, sink: sink),
            sleep: { seconds in
                waited = seconds
                eventsSeenDuringWait = sink.records.map(\.event)
            },
            crashAction: {}
        )

        faults.hang(seconds: 5)

        #expect(waited == 5)
        #expect(eventsSeenDuringWait == ["debug.hang.started"], "the start must be logged before the main thread blocks")
        #expect(sink.records.map(\.event) == ["debug.hang.started", "debug.hang.ended"])
        #expect(sink.records.map(\.publicFields) == [["seconds": .int(5)], ["seconds": .int(5)]])
        #expect(sink.records.allSatisfy { $0.category == .diagnostics && $0.level == .notice && $0.privateFields.isEmpty })
    }

    @Test func crashIsLoggedBeforeTheCrashActionRuns() {
        var eventsSeenAtCrash: [String] = []
        let faults = DebugFaults(
            log: CategoryLogger(.diagnostics, sink: sink),
            sleep: { _ in },
            crashAction: { eventsSeenAtCrash = sink.records.map(\.event) }
        )

        faults.crash()

        #expect(eventsSeenAtCrash == ["debug.crash.requested"], "the request must be logged before the app dies")
    }
}
#endif
