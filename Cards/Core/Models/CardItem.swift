import Foundation
import SwiftData

@Model
public final class CardItem: Identifiable {
    public var timestamp: Date = Date()
    public var code: String = ""
    public var name: String = ""
    public var order: Int = 0
    public var type: String = BarcodeType.code128.rawValue
    public var color: String = CardColor.standard.rawValue
    /// Where the card is used. Optional: most cards have none.
    public var locations: [CardLocation] = []
    /// Whether arriving at one of `locations` sends a reminder. Settings can turn
    /// them off for every card at once.
    public var notifiesOnArrival: Bool = true
    /// The SF Symbol that stands for the card, or nil for none.
    public var symbol: String?
    /// When the card was last opened, for sorting by last viewed; nil until it is.
    public var lastViewed: Date?

    public init(
        timestamp: Date = Date(),
        code: String,
        name: String,
        barcodeType: BarcodeType? = nil,
        order: Int? = nil,
        color: CardColor = .standard,
        locations: [CardLocation] = [],
        notifiesOnArrival: Bool = true,
        symbol: String? = nil,
        lastViewed: Date? = nil
    ) {
        self.timestamp = timestamp
        self.code = code
        self.name = name
        self.type = barcodeType?.rawValue ?? BarcodeType.code128.rawValue
        self.order = order ?? 0
        self.color = color.rawValue
        self.locations = locations
        self.notifiesOnArrival = notifiesOnArrival
        self.symbol = symbol
        self.lastViewed = lastViewed
    }

    public func getBarcodeType() -> BarcodeType {
        return BarcodeType(rawValue: type) ?? .code128
    }

    public func getColor() -> CardColor {
        CardColor.stored(color)
    }
}

public extension WidgetCard {
    /// What the widget needs from `card`. Lives here because the widget
    /// extension shares `WidgetCard` but not the store.
    init(_ card: CardItem) {
        self.init(
            code: card.code,
            name: card.name,
            barcodeType: card.getBarcodeType(),
            color: card.getColor(),
            locations: card.locations
        )
    }
}

public struct CardItemDTO: Codable {
    /// Every field but the name and code is optional, so older exports and
    /// hand-written files still import.
    public let timestamp: Date?
    public let code: String
    public let name: String
    public let order: Int?
    public let type: String?
    public let color: String?
    // swiftlint:disable:next discouraged_optional_collection
    public let locations: [CardLocation]?  // nil in exports made before locations existed
    // swiftlint:disable:next discouraged_optional_boolean
    public let notifiesOnArrival: Bool?  // nil in exports made before the per-card setting
    public let symbol: String?
    public let lastViewed: Date?

    public init(from card: CardItem) {
        timestamp = card.timestamp
        code = card.code
        name = card.name
        order = card.order
        type = card.type
        color = card.color
        locations = card.locations
        notifiesOnArrival = card.notifiesOnArrival
        symbol = card.symbol
        lastViewed = card.lastViewed
    }

    public func toCardItem() -> CardItem {
        CardItem(
            timestamp: timestamp ?? Date(),
            code: code,
            name: name,
            barcodeType: type.flatMap(BarcodeType.init(rawValue:)),
            order: order,
            color: CardColor.stored(color),
            locations: locations ?? [],
            notifiesOnArrival: notifiesOnArrival ?? true,
            symbol: symbol,
            lastViewed: lastViewed
        )
    }
}
