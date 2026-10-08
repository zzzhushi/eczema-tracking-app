import Foundation

/// The repository's reference data, read in place by tests.
let shippedDataDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "data", directoryHint: .isDirectory)
