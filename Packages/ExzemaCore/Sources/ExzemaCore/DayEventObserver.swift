import Foundation

/// Turns system clock notifications into `DayEvent.clockChanged` on a session.
///
/// Notifications are delivered synchronously when posted on the main thread and hop to it otherwise. The
/// notification center and the names are injected so tests can post their own; the app adds the
/// UIKit-only significant-time-change name.
@MainActor
public final class DayEventObserver {
    public static let foundationClockNotifications: [Notification.Name] = [.NSCalendarDayChanged, .NSSystemTimeZoneDidChange]

    private let subscription: Subscription

    public init(
        session: DaySession,
        center: NotificationCenter = .default,
        clockNotifications: [Notification.Name] = DayEventObserver.foundationClockNotifications
    ) {
        subscription = Subscription(center: center)
        let target = WeakSession(session)
        for name in clockNotifications {
            subscription.add(center.addObserver(forName: name, object: nil, queue: nil) { _ in
                target.deliver(.clockChanged)
            })
        }
    }
}

private final class WeakSession: @unchecked Sendable {
    private weak var session: DaySession?

    init(_ session: DaySession) { self.session = session }

    func deliver(_ event: DayEvent) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { session?.handle(event) }
        } else {
            DispatchQueue.main.async { MainActor.assumeIsolated { self.session?.handle(event) } }
        }
    }
}

/// Removes its observers when released, from whatever thread that happens on.
private final class Subscription: @unchecked Sendable {
    private let center: NotificationCenter
    private var tokens: [any NSObjectProtocol] = []

    init(center: NotificationCenter) { self.center = center }

    func add(_ token: any NSObjectProtocol) { tokens.append(token) }

    deinit { tokens.forEach(center.removeObserver) }
}
