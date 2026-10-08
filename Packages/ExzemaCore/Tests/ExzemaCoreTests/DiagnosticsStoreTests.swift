import Foundation
import Testing
import ExzemaCore

@Suite("Diagnostics store")
struct DiagnosticsStoreTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("DiagnosticsStoreTests-\(UUID().uuidString)", isDirectory: true)

    private let report = Data(#"{"callStackTree":[]}"#.utf8)

    private func instant(_ iso: String) -> Date {
        try! Date(iso, strategy: .iso8601)
    }

    @Test func savedReportKeepsItsExactBytes() throws {
        let store = DiagnosticsStore(directory: directory)

        let saved = try store.save(report, kind: .crash, receivedAt: instant("2026-10-07T20:00:00Z"))

        #expect(try Data(contentsOf: saved.url) == report)
        #expect(saved.kind == .crash)
    }

    @Test func reportsAreListedNewestFirst() throws {
        let store = DiagnosticsStore(directory: directory)
        try store.save(report, kind: .hang, receivedAt: instant("2026-10-06T08:00:00Z"))
        try store.save(report, kind: .crash, receivedAt: instant("2026-10-07T20:00:00Z"))

        #expect(try store.reports().map(\.kind) == [.crash, .hang])
    }

    @Test func twoReportsReceivedAtTheSameInstantAreBothKept() throws {
        let store = DiagnosticsStore(directory: directory)
        let moment = instant("2026-10-07T20:00:00Z")

        try store.save(report, kind: .crash, receivedAt: moment)
        try store.save(report, kind: .crash, receivedAt: moment)

        #expect(try store.reports().count == 2)
    }

    @Test func savedReportsAreExcludedFromBackup() throws {
        let store = DiagnosticsStore(directory: directory)
        let saved = try store.save(report, kind: .hang, receivedAt: instant("2026-10-07T20:00:00Z"))

        let values = try saved.url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
        #expect(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test func reportKindsCoverEveryKindTheSystemReportsPlusOneForNewKinds() {
        #expect(Set(DiagnosticKind.allCases.map(\.rawValue)) == [
            "crash", "hang", "cpuException", "diskWriteException", "appLaunch", "memoryException", "unknown",
        ])
    }

    @Test(arguments: DiagnosticKind.allCases)
    func everyKindIsSavedOnceAndListedWithItsOwnKind(kind: DiagnosticKind) throws {
        let store = DiagnosticsStore(directory: directory)

        try store.save(report, kind: kind, receivedAt: instant("2026-10-07T20:00:00Z"))

        #expect(try store.reports().map(\.kind) == [kind])
    }

    @Test func emptyStoreListsNoReports() throws {
        #expect(try DiagnosticsStore(directory: directory).reports().isEmpty)
    }
}
