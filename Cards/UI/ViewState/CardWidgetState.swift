import Foundation

/// A card reduced to what the Home Screen widget needs to draw itself.
public struct CardWidgetState: Hashable, Sendable {
    public let name: String
    public let code: String
    public let barcodeType: BarcodeType
    public let color: CardColor
    /// Distance to the nearest location, when the card has any and the user's
    /// location is known.
    public let proximity: CardProximity?

    public init(
        name: String,
        code: String,
        barcodeType: BarcodeType,
        color: CardColor = .standard,
        proximity: CardProximity? = nil
    ) {
        self.name = name
        self.code = code
        self.barcodeType = barcodeType
        self.color = color
        self.proximity = proximity
    }

    /// Opens this card in the app.
    public var url: URL? {
        NavigationRoute.card(code).url
    }
}
