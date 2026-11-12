import AVFoundation
@testable import Cards
import Foundation
import RSBarcodes_Swift
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
            let expectedWidth = CardGeometry.maximumBarcodeWidth
            let expectedHeight = CardGeometry.maximumBarcodeWidth / 3
            #expect(abs(image.size.width - expectedWidth) <= 1.0, "Image width should match expected width")
            #expect(abs(image.size.height - expectedHeight) <= 1.0, "Image height should match expected height")
        }
    }

    /// The card is as wide as its barcode at its widest with the white, the
    /// frame and the card's edge round it: 476 points, as CARD-4 says.
    @Test func theWidestCardIsAsWideAsItsWidestBarcode() {
        let round = 2 * (CardGeometry.barcodePlatePadding + CardGeometry.barcodeFrame + CardGeometry.inset)
        #expect(CardGeometry.maximumWidth == CardGeometry.maximumBarcodeWidth + round)
        #expect(CardGeometry.maximumWidth == 476)
    }

    @Test func barcodeOnWhiteAddsAQuietZone() throws {
        let image = try #require(
            BarcodeImage.onWhite("5012345678900", type: .ean13, size: CGSize(width: 300, height: 100), margin: 20)
        )
        #expect(image.size == CGSize(width: 340, height: 140))
        #expect(image.scale == 1)
        #expect(BarcodeImage.onWhite("nope", type: .ean13, size: CGSize(width: 300, height: 100), margin: 20) == nil)
    }
}
