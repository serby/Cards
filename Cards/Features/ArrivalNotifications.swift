import CoreLocation
import UserNotifications

/// Puts a card's barcode on the Lock Screen when you arrive at one of its
/// locations. Each location becomes a location-triggered local notification
/// carrying the barcode image, so iOS watches the places itself: no background
/// location, no server, and nothing running while the app is closed.
@MainActor
public enum ArrivalNotifier {
    /// What a card needs to be watched for. Hashable so callers can tell when
    /// anything relevant changed.
    public struct Card: Hashable, Sendable {
        public let name: String
        public let code: String
        public let barcodeType: BarcodeType
        public let locations: [CardLocation]

        public init(name: String, code: String, barcodeType: BarcodeType, locations: [CardLocation]) {
            self.name = name
            self.code = code
            self.barcodeType = barcodeType
            self.locations = locations
        }
    }

    /// One place to watch, and the card to show there.
    struct Arrival: Equatable {
        let card: Card
        let location: CardLocation
    }

    /// iOS watches at most 20 regions per app, so the nearest are kept.
    static let regionLimit = 20
    nonisolated static let codeKey = "code"

    // What was last scheduled; nil until the first run of this launch.
    // swiftlint:disable:next discouraged_optional_collection
    private static var scheduled: [Card]?

    /// Replaces every scheduled arrival with one per location of `cards`. Asks for
    /// notification permission the first time a card has a location.
    public static func reschedule(_ cards: [Card], near location: CLLocation?) async {
        guard cards != scheduled else { return }
        scheduled = cards

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let arrivals = plan(cards, near: location)
        guard !arrivals.isEmpty,
              (try? await center.requestAuthorization(options: [.alert, .sound])) == true else {
            return
        }
        for arrival in arrivals {
            try? await center.add(request(for: arrival))
        }
    }

    /// The places to watch, nearest first when `location` is known, capped at
    /// the region limit.
    static func plan(_ cards: [Card], near location: CLLocation?) -> [Arrival] {
        let arrivals = cards.flatMap { card in
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
        content.body = message(at: arrival.location.name)
        content.threadIdentifier = arrival.card.code
        content.userInfo = [codeKey: arrival.card.code]
        content.relevanceScore = 1
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

    /// The notification's text, under the card's name. Resolved now, in the
    /// app's language, because iOS shows the notification long after it is
    /// scheduled; every launch reschedules, so a change of language reaches
    /// it the next time the app opens.
    static func message(at placeName: String) -> String {
        String(
            localized: "You're at \(placeName). Your barcode is ready.",
            comment: "Lock Screen notification on arriving at one of a card's places, under the card's name. The argument is the place's name."
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
