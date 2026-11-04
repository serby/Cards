import CoreLocation
import Foundation

/// What the Home Screen widget knows about a card. The widget cannot open the
/// app's store, so the app writes every card to a shared file (`WidgetSnapshot`)
/// and the widget reads it from there.
public struct WidgetCard: Codable, Hashable, Identifiable, Sendable {
    public let code: String
    public let name: String
    public let barcodeType: BarcodeType
    public let color: CardColor
    public let locations: [CardLocation]

    public var id: String { code }

    public init(code: String, name: String, barcodeType: BarcodeType, color: CardColor, locations: [CardLocation]) {
        self.code = code
        self.name = name
        self.barcodeType = barcodeType
        self.color = color
        self.locations = locations
    }
}

public extension WidgetCard {
    /// The card drawn by the widget, with how far away its nearest location is.
    func state(near location: CLLocation?) -> CardWidgetState {
        CardWidgetState(
            name: name,
            code: code,
            barcodeType: barcodeType,
            color: color,
            proximity: locations.proximity(to: location)
        )
    }
}

public extension Collection<WidgetCard> {
    /// The card whose nearest location is closest to `location`. Falls back to the
    /// first card, the top of the user's list, when no card has a location or
    /// `location` is unknown.
    func nearest(to location: CLLocation?) -> WidgetCard? {
        let placed = compactMap { card in
            card.locations.proximity(to: location).map { (card: card, distance: $0.distance) }
        }
        return placed.min { $0.distance < $1.distance }?.card ?? first
    }
}
