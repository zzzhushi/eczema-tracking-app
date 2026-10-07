import Foundation

enum AppPaths {
    /// The app's private storage; the store and diagnostics each get a dedicated directory beneath it.
    static func applicationSupport() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("eXzema", isDirectory: true)
    }
}
