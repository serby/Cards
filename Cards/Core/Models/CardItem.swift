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

    public init(
        timestamp: Date = Date(),
        code: String,
        name: String,
        barcodeType: BarcodeType? = nil,
        order: Int? = nil,
        color: CardColor = .standard,
        locations: [CardLocation] = []
    ) {
        self.timestamp = timestamp
        self.code = code
        self.name = name
        self.type = barcodeType?.rawValue ?? BarcodeType.code128.rawValue
        self.order = order ?? 0
        self.color = color.rawValue
        self.locations = locations
    }

    public func getBarcodeType() -> BarcodeType {
        return BarcodeType(rawValue: type) ?? .code128
    }

    public func getColor() -> CardColor {
        CardColor.stored(color)
    }
}

public struct CardItemDTO: Codable {
    public let timestamp: Date
    public let code: String
    public let name: String
    public let order: Int
    public let type: String
    /// Optional so exports made before these fields existed still import.
    public let color: String?
    // swiftlint:disable:next discouraged_optional_collection
    public let locations: [CardLocation]?  // nil in exports made before locations existed

    public init(from card: CardItem) {
        timestamp = card.timestamp
        code = card.code
        name = card.name
        order = card.order
        type = card.type
        color = card.color
        locations = card.locations
    }

    public func toCardItem() -> CardItem {
        CardItem(
            timestamp: timestamp,
            code: code,
            name: name,
            barcodeType: BarcodeType(rawValue: type),
            order: order,
            color: CardColor.stored(color),
            locations: locations ?? []
        )
    }
}
