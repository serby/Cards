import Foundation
import SwiftData

@Model
public final class CardItem: Identifiable {
    public var timestamp: Date = Date()
    public var code: String = ""
    public var name: String = ""
    public var order: Int = 0
    public var type: String = BarcodeType.code128.rawValue

    public init(timestamp: Date = Date(), code: String, name: String, barcodeType: BarcodeType? = nil, order: Int? = nil) {
        self.timestamp = timestamp
        self.code = code
        self.name = name
        self.type = barcodeType?.rawValue ?? BarcodeType.code128.rawValue
        self.order = order ?? 0
    }

    public func getBarcodeType() -> BarcodeType {
        return BarcodeType(rawValue: type) ?? .code128
    }
}

public struct CardItemDTO: Codable {
    public let timestamp: Date
    public let code: String
    public let name: String
    public let order: Int
    public let type: String

    public init(from card: CardItem) {
        timestamp = card.timestamp
        code = card.code
        name = card.name
        order = card.order
        type = card.type
    }

    public func toCardItem() -> CardItem {
        CardItem(
            timestamp: timestamp,
            code: code,
            name: name,
            barcodeType: BarcodeType(rawValue: type),
            order: order
        )
    }
}
