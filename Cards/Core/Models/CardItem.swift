//
//  CardItem.swift
//  Cards
//
//  Created by Serby, Paul on 18/12/2024.
//

import Foundation
import SwiftData

@Model
public final class CardItem: Identifiable {
    var timestamp: Date = Date()
    var code: String = ""
    var name: String = ""
    var order: Int = 0
    var type: String = BarcodeType.code128.rawValue
    
    init(timestamp: Date = Date(), code: String, name: String, barcodeType: BarcodeType? = nil, order: Int? = nil) {
        self.timestamp = timestamp
        self.code = code
        self.name = name
        self.type = barcodeType?.rawValue ?? BarcodeType.code128.rawValue
        self.order = order ?? 0
    }
    
    func getBarcodeType() -> BarcodeType {
        return BarcodeType(rawValue: type) ?? .code128
    }
}

struct CardItemDTO: Codable {
    let timestamp: Date
    let code: String
    let name: String
    let order: Int
    let type: String
    
    init(from card: CardItem) {
        timestamp = card.timestamp
        code = card.code
        name = card.name
        order = card.order
        type = card.type
    }
    
    func toCardItem() -> CardItem {
        CardItem(
            timestamp: timestamp,
            code: code,
            name: name,
            barcodeType: BarcodeType(rawValue: type),
            order: order
        )
    }
}
