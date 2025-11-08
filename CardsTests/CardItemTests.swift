//
//  CardItemTests.swift
//  CardsTests
//
//  Created by Serby, Paul on 04/06/2025.
//

@testable import Cards
import SwiftData
import XCTest

final class CardItemTests: XCTestCase {
    
    // Test initialization with all parameters
    func testInitWithAllParameters() {
        let timestamp = Date()
        let code = "1234567890"
        let name = "Test Card"
        let barcodeType = BarcodeType.qrCode
        let order = 5
        
        let cardItem = CardItem(timestamp: timestamp, code: code, name: name, barcodeType: barcodeType, order: order)
        
        XCTAssertEqual(cardItem.timestamp, timestamp)
        XCTAssertEqual(cardItem.code, code)
        XCTAssertEqual(cardItem.name, name)
        XCTAssertEqual(cardItem.getBarcodeType(), barcodeType)
        XCTAssertEqual(cardItem.order, order)
        XCTAssertEqual(cardItem.type, barcodeType.rawValue)
    }
    
    // Test initialization with default parameters
    func testInitWithDefaultParameters() {
        let timestamp = Date()
        let code = "1234567890"
        let name = "Test Card"
        
        let cardItem = CardItem(timestamp: timestamp, code: code, name: name)
        
        XCTAssertEqual(cardItem.timestamp, timestamp)
        XCTAssertEqual(cardItem.code, code)
        XCTAssertEqual(cardItem.name, name)
        XCTAssertEqual(cardItem.getBarcodeType(), .code128) // Default value
        XCTAssertEqual(cardItem.order, 0) // Default value
        XCTAssertEqual(cardItem.type, BarcodeType.code128.rawValue)
    }
    
    // Test barcodeType computed property getter
    func testBarcodeTypeGetter() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card")
        cardItem.type = BarcodeType.ean13.rawValue
        
        XCTAssertEqual(cardItem.getBarcodeType(), .ean13)
    }
    
    // Test barcodeType computed property setter
    func testBarcodeTypeSetter() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card")
        cardItem.type = BarcodeType.pdf417.rawValue
        
        XCTAssertEqual(cardItem.type, BarcodeType.pdf417.rawValue)
    }
    
    // Test getBarcodeType with invalid type
    func testBarcodeTypeWithNilType() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card")
        cardItem.type = ""
        
        // Should default to code128 when type is empty
        XCTAssertEqual(cardItem.getBarcodeType(), .code128)
    }
    
    // Test barcodeType with invalid type
    func testBarcodeTypeWithInvalidType() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card")
        cardItem.type = "Invalid Type"
        
        // Should default to code128 when type is invalid
        XCTAssertEqual(cardItem.getBarcodeType(), .code128)
    }
    
    // Test Identifiable conformance
    func testIdentifiableConformance() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card")
        
        // The id property should be accessible
        _ = cardItem.id
        
        // This is more of a compile-time check that CardItem conforms to Identifiable
        XCTAssertTrue(true)
    }
}
