import ExzemaCore
import Foundation
import MetricKit

/// Saves crash and hang reports delivered by MetricKit to the diagnostics store; nothing leaves the phone.
final class DiagnosticsSubscriber: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    private let store: DiagnosticsStore

    override init() {
        let directory = (try? AppPaths.applicationSupport())?
            .appendingPathComponent("Diagnostics", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("Diagnostics", isDirectory: true)
        store = DiagnosticsStore(directory: directory)
        super.init()
        MXMetricManager.shared.add(self)
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let json = payload.jsonRepresentation()
            if payload.crashDiagnostics?.isEmpty == false { save(json, kind: .crash) }
            if payload.hangDiagnostics?.isEmpty == false { save(json, kind: .hang) }
        }
    }

    private func save(_ json: Data, kind: DiagnosticKind) {
        do {
            try store.save(json, kind: kind, receivedAt: Date())
            switch kind {
            case .crash: Log.diagnostics.notice("report.saved", public: ["kind": "crash"])
            case .hang: Log.diagnostics.notice("report.saved", public: ["kind": "hang"])
            }
        } catch {
            Log.diagnostics.error("report.saveFailed", private: ["error": String(describing: error)])
        }
    }
}
