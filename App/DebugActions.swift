import ExzemaCore

#if DEBUG
enum DebugActions {
    static func crash() {
        DebugFaults().crash()
    }

    static func hang() {
        DebugFaults().hang(seconds: 5)
    }
}
#endif
