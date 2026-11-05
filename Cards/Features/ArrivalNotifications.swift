import CoreLocation
import UserNotifications

/// Reminds you of a card when you arrive at one of its locations. Each location
/// becomes a location-triggered local notification, so iOS watches the places
/// itself: no background location, no server, and nothing running while the app
/// is closed. Tapping the notification opens the card.
@MainActor
public enum ArrivalNotifier {
    /// What a card needs to be watched for. Hashable so callers can tell when
    /// anything relevant changed.
    public struct Card: Hashable, Sendable {
        public let name: String
        public let code: String
        public let barcodeType: BarcodeType
        public let locations: [CardLocation]
        /// The card's own switch; a card that is off is never watched.
        public let notifies: Bool

        public init(name: String, code: String, barcodeType: BarcodeType, locations: [CardLocation], notifies: Bool = true) {
            self.name = name
            self.code = code
            self.barcodeType = barcodeType
            self.locations = locations
            self.notifies = notifies
        }
    }

    /// One place to watch, and the card to show there.
    struct Arrival: Hashable {
        let card: Card
        let location: CardLocation
    }

    /// The Settings switch for arrival notifications (a `UserDefaults` key).
    /// On unless the user turns it off.
    public static let enabledKey = "arrivalNotifications"

    /// iOS watches at most 20 regions per app, so the nearest are kept.
    static let regionLimit = 20
    nonisolated static let codeKey = "code"

    // What was last scheduled; nil until the first run of this launch.
    // swiftlint:disable:next discouraged_optional_collection
    private static var scheduled: Set<Arrival>?

    /// Replaces every scheduled arrival with one per location of `cards`. Asks for
    /// notification permission the first time a card has a location.
    /// Called again as you move, so with more than `regionLimit` places the nearest
    /// are watched; it does nothing unless the set of places to watch has changed.
    public static func reschedule(_ cards: [Card], near location: CLLocation?) async {
        let arrivals = plan(cards, near: location)
        guard Set(arrivals) != scheduled else { return }
        scheduled = Set(arrivals)

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard !arrivals.isEmpty,
              (try? await center.requestAuthorization(options: [.alert, .sound])) == true else {
            return
        }
        for arrival in arrivals {
            try? await center.add(request(for: arrival))
        }
    }

    /// Whether notifications are switched off for the app in the Settings app,
    /// so arrivals cannot show however the in-app switch is set.
    public static func isBlockedInSettings() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    /// A cell of roughly a kilometre round `location`. The list screen plans the
    /// arrivals again when it changes, which is often enough for the nearest
    /// places to stay the ones watched.
    public static func area(of location: CLLocation?) -> [Int]? { // swiftlint:disable:this discouraged_optional_collection
        location.map { location in
            [Int((location.coordinate.latitude * 100).rounded()), Int((location.coordinate.longitude * 100).rounded())]
        }
    }

    /// The places to watch, nearest first when `location` is known, capped at
    /// the region limit.
    static func plan(_ cards: [Card], near location: CLLocation?) -> [Arrival] {
        let arrivals = cards.filter(\.notifies).flatMap { card in
            card.locations.map { Arrival(card: card, location: $0) }
        }
        guard let location else { return Array(arrivals.prefix(regionLimit)) }
        return Array(
            arrivals
                .sorted { $0.location.distance(from: location) < $1.location.distance(from: location) }
                .prefix(regionLimit)
        )
    }

    private static func request(for arrival: Arrival) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = arrival.card.name
        content.body = "You're at \(arrival.location.name). Your barcode is ready."
        content.threadIdentifier = arrival.card.code
        content.userInfo = [codeKey: arrival.card.code]
        content.relevanceScore = 1
        content.sound = .default
        if let attachment = barcodeAttachment(for: arrival.card) {
            content.attachments = [attachment]
        }

        let region = CLCircularRegion(
            center: arrival.location.coordinate,
            radius: arrival.location.radius,
            identifier: arrival.location.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false

        return UNNotificationRequest(
            identifier: "arrival.\(arrival.location.id.uuidString)",
            content: content,
            trigger: UNLocationNotificationTrigger(region: region, repeats: true)
        )
    }

    /// The barcode as an image file. iOS moves the file into its own store when
    /// the request is added, so each request gets a fresh one.
    private static func barcodeAttachment(for card: Card) -> UNNotificationAttachment? {
        guard let png = BarcodeImage.pngOnWhite(card.code, type: card.barcodeType) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("barcode-\(UUID().uuidString).png")
        guard (try? png.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "barcode", url: url)
    }
}

/// Opens the card when an arrival notification is tapped, and still shows the
/// notification if the app is already open.
@MainActor
public final class ArrivalNotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    private let openCard: (String) -> Void

    public init(openCard: @escaping (String) -> Void) {
        self.openCard = openCard
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let code = response.notification.request.content.userInfo[ArrivalNotifier.codeKey] as? String else {
            return
        }
        await open(code)
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    private func open(_ code: String) {
        openCard(code)
    }
}
