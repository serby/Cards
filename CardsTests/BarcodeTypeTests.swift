//
//  BarcodeTypeTests.swift
//  CardsTests
//
//  Created by Serby, Paul on 04/06/2025.
//

import AVFoundation
@testable import Cards
import XCTest

final class BarcodeTypeTests: XCTestCase {
    
    // Test mapping from BarcodeType to AVMetadataObject.ObjectType
    func testMapBarcodeTypeToMetadataObjectType() {
        // Test all enum cases
        XCTAssertEqual(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.code128), .code128)
        XCTAssertEqual(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.code39), .code39)
        XCTAssertEqual(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.qrCode), .qr)
        XCTAssertEqual(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.ean8), .ean8)
        XCTAssertEqual(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.ean13), .ean13)
        XCTAssertEqual(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.pdf417), .pdf417)
        XCTAssertEqual(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.upce), .upce)
        XCTAssertEqual(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.aztec), .aztec)
        XCTAssertEqual(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.code93), .code93)
    }
    
    // Test mapping from AVMetadataObject.ObjectType to BarcodeType
    func testMapMetadataObjectTypeToBarcodeType() {
        // Test all supported types
        XCTAssertEqual(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.code128), .code128)
        XCTAssertEqual(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.code39), .code39)
        XCTAssertEqual(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.qr), .qrCode)
        XCTAssertEqual(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.ean8), .ean8)
        XCTAssertEqual(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.ean13), .ean13)
        XCTAssertEqual(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.pdf417), .pdf417)
        XCTAssertEqual(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.upce), .upce)
        XCTAssertEqual(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.aztec), .aztec)
        XCTAssertEqual(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.code93), .code93)
        
        // Test unsupported type
        XCTAssertNil(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.face))
        XCTAssertNil(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.itf14))
        XCTAssertNil(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.dataMatrix))
    }
    
    // Test BarcodeType raw values
    func testBarcodeTypeRawValues() {
        XCTAssertEqual(BarcodeType.code128.rawValue, "Code 128")
        XCTAssertEqual(BarcodeType.code39.rawValue, "Code 39")
        XCTAssertEqual(BarcodeType.qrCode.rawValue, "QR Code")
        XCTAssertEqual(BarcodeType.ean8.rawValue, "EAN-8")
        XCTAssertEqual(BarcodeType.ean13.rawValue, "EAN-13")
        XCTAssertEqual(BarcodeType.code93.rawValue, "Code 93")
        XCTAssertEqual(BarcodeType.upce.rawValue, "UPC-E")
        XCTAssertEqual(BarcodeType.aztec.rawValue, "Aztec")
        XCTAssertEqual(BarcodeType.pdf417.rawValue, "PDF 417")
    }
    
    // Test BarcodeType initialization from raw value
    func testBarcodeTypeInitFromRawValue() {
        XCTAssertEqual(BarcodeType(rawValue: "Code 128"), .code128)
        XCTAssertEqual(BarcodeType(rawValue: "Code 39"), .code39)
        XCTAssertEqual(BarcodeType(rawValue: "QR Code"), .qrCode)
        XCTAssertEqual(BarcodeType(rawValue: "EAN-8"), .ean8)
        XCTAssertEqual(BarcodeType(rawValue: "EAN-13"), .ean13)
        XCTAssertEqual(BarcodeType(rawValue: "Code 93"), .code93)
        XCTAssertEqual(BarcodeType(rawValue: "UPC-E"), .upce)
        XCTAssertEqual(BarcodeType(rawValue: "Aztec"), .aztec)
        XCTAssertEqual(BarcodeType(rawValue: "PDF 417"), .pdf417)
        
        // Test invalid raw value
        XCTAssertNil(BarcodeType(rawValue: "Invalid Type"))
    }
    
    // Test BarcodeType CaseIterable conformance
    func testBarcodeTypeCaseIterable() {
        let allCases = BarcodeType.allCases
        
        // Check that all cases are included
        XCTAssertEqual(allCases.count, 9)
        XCTAssertTrue(allCases.contains(.code128))
        XCTAssertTrue(allCases.contains(.code39))
        XCTAssertTrue(allCases.contains(.qrCode))
        XCTAssertTrue(allCases.contains(.ean8))
        XCTAssertTrue(allCases.contains(.ean13))
        XCTAssertTrue(allCases.contains(.code93))
        XCTAssertTrue(allCases.contains(.upce))
        XCTAssertTrue(allCases.contains(.aztec))
        XCTAssertTrue(allCases.contains(.pdf417))
    }
    
    // Test BarcodeType Hashable conformance
    func testBarcodeTypeHashable() {
        var barcodeSet = Set<BarcodeType>()
        
        // Add all cases to the set
        barcodeSet.insert(.code128)
        barcodeSet.insert(.code39)
        barcodeSet.insert(.qrCode)
        barcodeSet.insert(.ean8)
        barcodeSet.insert(.ean13)
        barcodeSet.insert(.code93)
        barcodeSet.insert(.upce)
        barcodeSet.insert(.aztec)
        barcodeSet.insert(.pdf417)
        
        // Check that all cases are in the set
        XCTAssertEqual(barcodeSet.count, 9)
        
        // Check that duplicates are not added
        barcodeSet.insert(.code128)
        XCTAssertEqual(barcodeSet.count, 9)
    }
}
