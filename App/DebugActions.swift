import Foundation

#if DEBUG
/// Provokes the failures that crash and hang collection must catch; absent from Release builds.
enum DebugActions {
    static func crash() -> Never {
        preconditionFailure("Crash requested from the debug section")
    }

    static func hang() {
        Thread.sleep(forTimeInterval: 5)
    }
}
#endif
