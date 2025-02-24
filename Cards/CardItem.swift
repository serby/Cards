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
    var timestamp: Date
    var code: String
    var name: String
    var order: Int?
    
    // Store the raw value of the BarcodeType
    var type: String?
    
    // Computed property for convenient access as BarcodeType
    var barcodeType: BarcodeType {
        get { BarcodeType(rawValue: type ?? "Code 128" ) ?? .code128 }
        set { type = newValue.rawValue }
    }
    
    init(timestamp: Date, code: String, name: String, barcodeType: BarcodeType? = nil, order: Int? = nil) {
        self.timestamp = timestamp
        self.code = code
        self.name = name
        self.barcodeType = barcodeType ?? .code128
        self.order = order ?? 0
    }
}
