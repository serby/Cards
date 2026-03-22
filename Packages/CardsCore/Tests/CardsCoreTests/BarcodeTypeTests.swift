import AVFoundation
@testable import CardsCore
import Foundation
import Testing

struct BarcodeTypeTests {

    @Test func mapBarcodeTypeToMetadataObjectType() {
        #expect(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.code128) == .code128)
        #expect(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.code39) == .code39)
        #expect(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.qrCode) == .qr)
        #expect(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.ean8) == .ean8)
        #expect(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.ean13) == .ean13)
        #expect(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.pdf417) == .pdf417)
        #expect(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.upce) == .upce)
        #expect(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.aztec) == .aztec)
        #expect(BarcodeMapper.mapBarcodeTypeToMetadataObjectType(.code93) == .code93)
    }

    @Test func mapMetadataObjectTypeToBarcodeType() {
        #expect(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.code128) == .code128)
        #expect(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.code39) == .code39)
        #expect(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.qr) == .qrCode)
        #expect(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.ean8) == .ean8)
        #expect(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.ean13) == .ean13)
        #expect(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.pdf417) == .pdf417)
        #expect(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.upce) == .upce)
        #expect(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.aztec) == .aztec)
        #expect(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.code93) == .code93)
        #expect(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.face) == nil)
        #expect(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.itf14) == nil)
        #expect(BarcodeMapper.mapMetadataObjectTypeToBarcodeType(.dataMatrix) == nil)
    }

    @Test func barcodeTypeRawValues() {
        #expect(BarcodeType.code128.rawValue == "Code 128")
        #expect(BarcodeType.code39.rawValue == "Code 39")
        #expect(BarcodeType.qrCode.rawValue == "QR Code")
        #expect(BarcodeType.ean8.rawValue == "EAN-8")
        #expect(BarcodeType.ean13.rawValue == "EAN-13")
        #expect(BarcodeType.code93.rawValue == "Code 93")
        #expect(BarcodeType.upce.rawValue == "UPC-E")
        #expect(BarcodeType.aztec.rawValue == "Aztec")
        #expect(BarcodeType.pdf417.rawValue == "PDF 417")
    }

    @Test func barcodeTypeInitFromRawValue() {
        #expect(BarcodeType(rawValue: "Code 128") == .code128)
        #expect(BarcodeType(rawValue: "Code 39") == .code39)
        #expect(BarcodeType(rawValue: "QR Code") == .qrCode)
        #expect(BarcodeType(rawValue: "EAN-8") == .ean8)
        #expect(BarcodeType(rawValue: "EAN-13") == .ean13)
        #expect(BarcodeType(rawValue: "Code 93") == .code93)
        #expect(BarcodeType(rawValue: "UPC-E") == .upce)
        #expect(BarcodeType(rawValue: "Aztec") == .aztec)
        #expect(BarcodeType(rawValue: "PDF 417") == .pdf417)
        #expect(BarcodeType(rawValue: "Invalid Type") == nil)
    }

    @Test func barcodeTypeCaseIterable() {
        let allCases = BarcodeType.allCases
        #expect(allCases.count == 9)
        #expect(allCases.contains(.code128))
        #expect(allCases.contains(.code39))
        #expect(allCases.contains(.qrCode))
        #expect(allCases.contains(.ean8))
        #expect(allCases.contains(.ean13))
        #expect(allCases.contains(.code93))
        #expect(allCases.contains(.upce))
        #expect(allCases.contains(.aztec))
        #expect(allCases.contains(.pdf417))
    }

    @Test func barcodeTypeHashable() {
        var barcodeSet = Set<BarcodeType>()
        barcodeSet.insert(.code128)
        barcodeSet.insert(.code39)
        barcodeSet.insert(.qrCode)
        barcodeSet.insert(.ean8)
        barcodeSet.insert(.ean13)
        barcodeSet.insert(.code93)
        barcodeSet.insert(.upce)
        barcodeSet.insert(.aztec)
        barcodeSet.insert(.pdf417)
        #expect(barcodeSet.count == 9)
        barcodeSet.insert(.code128)
        #expect(barcodeSet.count == 9)
    }
}
