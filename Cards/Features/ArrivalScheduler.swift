import CoreLocation
import Observation
import UserNotifications

/// Reminds you of a card when you arrive at one of its locations. Each location
/// becomes a location-triggered local notification, so iOS watches the places
/// itself: no background location, no server, and nothing running while the app
/// is closed. Tapping the notification opens the card (`ArrivalNotificationRouter`).
/// Created once by `CardsApp`, which owns what was last scheduled.
@MainActor
@Observable
public final class ArrivalScheduler {
    @ObservationIgnored private let notifications: NotificationClient
    // What was last scheduled; nil until the first run of this launch.
    // swiftlint:disable:next discouraged_optional_collection
    @ObservationIgnored private var scheduled: Set<ArrivalPlan.Arrival>?

    public init(notifications: NotificationClient = .live) {
        self.notifications = notifications
    }

    /// Replaces every scheduled arrival with one per location of `cards`. Asks for
    /// notification permission the first time a card has a location.
    /// Called again as you move, so with more than `ArrivalPlan.regionLimit` places
    /// the nearest are watched; it does nothing unless the set of places to watch
    /// has changed.
    public func reschedule(_ cards: [ArrivalPlan.Card], near location: CLLocation?) async {
        let arrivals = ArrivalPlan.arrivals(for: cards, near: location)
        guard Set(arrivals) != scheduled else { return }
        scheduled = Set(arrivals)

        notifications.removeAllPending()

        guard !arrivals.isEmpty, (try? await notifications.requestAuthorization()) == true else {
            return
        }
        for arrival in arrivals {
            try? await notifications.add(ArrivalPlan.alert(for: arrival))
        }
    }

    /// Whether notifications are switched off for the app in the Settings app,
    /// so arrivals cannot show however the in-app switch is set.
    public func isBlockedInSettings() async -> Bool {
        await notifications.authorizationStatus() == .denied
    }
}
