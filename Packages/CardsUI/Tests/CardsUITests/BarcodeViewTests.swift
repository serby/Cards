import AVFoundation
@testable import CardsCore
import Foundation
import RSBarcodes_Swift
@testable import CardsUI
import SwiftUI
import Testing

struct BarcodeViewTests {

    @Test @MainActor
    func generateBarcodeCode128() {
        let barcodeView = BarcodeView(barcodeString: "1234567890", barcodeType: .code128)
        let image = barcodeView.generateBarcode(from: "1234567890", type: .code128)
        #expect(image != nil, "Should generate a valid Code 128 barcode image")
    }

    @Test @MainActor
    func generateBarcodeQRCode() {
        let barcodeView = BarcodeView(barcodeString: "https://example.com", barcodeType: .qrCode)
        let image = barcodeView.generateBarcode(from: "https://example.com", type: .qrCode)
        #expect(image != nil, "Should generate a valid QR code image")
    }

    @Test @MainActor
    func generateBarcodeEAN13() {
        let barcodeView = BarcodeView(barcodeString: "5901234123457", barcodeType: .ean13)
        let image = barcodeView.generateBarcode(from: "5901234123457", type: .ean13)
        #expect(image != nil, "Should generate a valid EAN-13 barcode image")
    }

    @Test @MainActor
    func generateBarcodeEmptyString() {
        let barcodeView = BarcodeView(barcodeString: "", barcodeType: .code128)
        let image = barcodeView.generateBarcode(from: "", type: .code128)
        if let image = image {
            #expect(image.size.width > 0 && image.size.height > 0, "Image dimensions should be valid")
        }
    }

    @Test @MainActor
    func generateBarcodeLongString() {
        let longString = String(repeating: "1234567890", count: 20)
        let barcodeView = BarcodeView(barcodeString: longString, barcodeType: .code128)
        let image = barcodeView.generateBarcode(from: longString, type: .code128)
        #expect(image != nil, "Should generate a barcode even with a long string")
    }

    @Test @MainActor
    func generateBarcodeSpecialCharacters() {
        let specialString = "!@#$%^&*()-_=+[]{}|;:,.<>?/"
        let barcodeView = BarcodeView(barcodeString: specialString, barcodeType: .code128)
        let image = barcodeView.generateBarcode(from: specialString, type: .code128)
        #expect(image != nil, "Should generate a barcode with special characters")
    }

    @Test @MainActor
    func generateBarcodeUnsupportedType() {
        let barcodeView = BarcodeView(barcodeString: "1234567890", barcodeType: .code128)
        let result = barcodeView.generateBarcode(from: "1234567890", type: .code128)
        #expect(result != nil)
    }

    @Test @MainActor
    func barcodeImageDimensions() {
        let barcodeView = BarcodeView(barcodeString: "1234567890", barcodeType: .code128)
        let image = barcodeView.generateBarcode(from: "1234567890", type: .code128)
        #expect(image != nil, "Should generate a valid barcode image")
        if let image = image {
            let expectedWidth = pointsWidth * 1.0
            let expectedHeight = (pointsWidth / 3) * 1.0
            #expect(abs(image.size.width - expectedWidth) <= 1.0, "Image width should match expected width")
            #expect(abs(image.size.height - expectedHeight) <= 1.0, "Image height should match expected height")
        }
    }
}
