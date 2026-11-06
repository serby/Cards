import CoreLocation
import Foundation

/// Which places to watch for arrival notifications, and what each notification
/// says. Pure: `ArrivalScheduler` hands the result to the notification client.
public enum ArrivalPlan {
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
    struct Arrival: Hashable, Sendable {
        let card: Card
        let location: CardLocation
    }

    /// The Settings switch for arrival notifications (a `UserDefaults` key).
    /// On unless the user turns it off.
    public static let enabledKey = "arrivalNotifications"

    /// iOS watches at most 20 regions per app, so the nearest are kept.
    static let regionLimit = 20

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
    static func arrivals(for cards: [Card], near location: CLLocation?) -> [Arrival] {
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

    /// The notification for `arrival`, with the card's barcode attached.
    static func alert(for arrival: Arrival) -> ArrivalAlert {
        ArrivalAlert(
            id: "arrival.\(arrival.location.id.uuidString)",
            title: arrival.card.name,
            body: "You're at \(arrival.location.name). Your barcode is ready.",
            code: arrival.card.code,
            barcodePNG: BarcodeImage.pngOnWhite(arrival.card.code, type: arrival.card.barcodeType),
            place: arrival.location
        )
    }
}
