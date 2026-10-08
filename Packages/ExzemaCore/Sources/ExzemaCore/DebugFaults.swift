#if DEBUG
import Foundation

/// Provokes the crash and hang that diagnostics collection must catch, and logs each so a report can be matched to it.
///
/// Compiled only into Debug builds.
public struct DebugFaults {
    private let log: CategoryLogger
    private let sleep: (TimeInterval) -> Void
    private let crashAction: () -> Void

    public init(
        log: CategoryLogger = Log.diagnostics,
        sleep: @escaping (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) },
        crashAction: @escaping () -> Void = { preconditionFailure("Crash requested from the debug section") }
    ) {
        self.log = log
        self.sleep = sleep
        self.crashAction = crashAction
    }

    /// Block the calling thread for `seconds`; call from the main thread to freeze the interface.
    public func hang(seconds: Int = 5) {
        log.notice("debug.hang.started", public: ["seconds": .int(seconds)])
        sleep(TimeInterval(seconds))
        log.notice("debug.hang.ended", public: ["seconds": .int(seconds)])
    }

    public func crash() {
        log.notice("debug.crash.requested")
        crashAction()
    }
}
#endif
