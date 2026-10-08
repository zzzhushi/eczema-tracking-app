import ExzemaCore
import Foundation
import MetricKit

/// Saves every diagnostic report the system delivers, one file per report; nothing leaves the phone.
///
/// Holds the metric manager and the listening task for the life of the app, so reports delivered at launch are not missed.
final class DiagnosticsListener: Sendable {
    private let manager: MetricManager
    private let task: Task<Void, Never>

    init() {
        let manager = MetricManager()
        let directory = (try? AppPaths.applicationSupport())?.appendingPathComponent("Diagnostics", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("Diagnostics", isDirectory: true)
        let store = DiagnosticsStore(directory: directory)

        self.manager = manager
        task = Task.detached(priority: .utility) {
            for await report in manager.diagnosticReports {
                Self.save(report, in: store)
            }
        }
    }

    deinit {
        task.cancel()
    }

    private static func save(_ report: DiagnosticReport, in store: DiagnosticsStore) {
        let (kind, fields) = describe(report.result)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            try store.save(try encoder.encode(report), kind: kind, receivedAt: Date())
            Log.diagnostics.notice("report.saved", public: fields)
        } catch {
            Log.diagnostics.error("report.saveFailed", private: ["error": String(describing: error)])
        }
    }

    /// The kind to file a report under and the public log fields that describe it.
    private static func describe(_ result: DiagnosticResult) -> (DiagnosticKind, [LogKey: PublicLogValue]) {
        switch result {
        case .crash: (.crash, ["kind": "crash"])
        case .hang(let hang):
            (.hang, ["kind": "hang", "durationMs": .int(Int(hang.hangDuration.converted(to: .milliseconds).value))])
        case .cpuException: (.cpuException, ["kind": "cpuException"])
        case .diskWriteException: (.diskWriteException, ["kind": "diskWriteException"])
        case .appLaunch: (.appLaunch, ["kind": "appLaunch"])
        case .memoryException: (.memoryException, ["kind": "memoryException"])
        @unknown default: (.unknown, ["kind": "unknown"])
        }
    }
}
