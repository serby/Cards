@testable import Cards
import Foundation
import SwiftData
import Testing

struct CardItemTests {

    @Test func initWithAllParameters() {
        let timestamp = Date()
        let code = "1234567890"
        let name = "Test Card"
        let barcodeType = BarcodeType.qrCode
        let order = 5

        let cardItem = CardItem(timestamp: timestamp, code: code, name: name, barcodeType: barcodeType, order: order)

        #expect(cardItem.timestamp == timestamp)
        #expect(cardItem.code == code)
        #expect(cardItem.name == name)
        #expect(cardItem.getBarcodeType() == barcodeType)
        #expect(cardItem.order == order)
        #expect(cardItem.type == barcodeType.rawValue)
    }

    @Test func initWithDefaultParameters() {
        let timestamp = Date()
        let code = "1234567890"
        let name = "Test Card"

        let cardItem = CardItem(timestamp: timestamp, code: code, name: name)

        #expect(cardItem.timestamp == timestamp)
        #expect(cardItem.code == code)
        #expect(cardItem.name == name)
        #expect(cardItem.getBarcodeType() == .code128)
        #expect(cardItem.order == 0)
        #expect(cardItem.type == BarcodeType.code128.rawValue)
    }

    @Test func barcodeTypeGetter() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card")
        cardItem.type = BarcodeType.ean13.rawValue
        #expect(cardItem.getBarcodeType() == .ean13)
    }

    @Test func barcodeTypeSetter() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card")
        cardItem.type = BarcodeType.pdf417.rawValue
        #expect(cardItem.type == BarcodeType.pdf417.rawValue)
    }

    @Test func barcodeTypeWithNilType() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card")
        cardItem.type = ""
        #expect(cardItem.getBarcodeType() == .code128)
    }

    @Test func barcodeTypeWithInvalidType() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card")
        cardItem.type = "Invalid Type"
        #expect(cardItem.getBarcodeType() == .code128)
    }

    @Test func colourDefaultsToStandard() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card")
        #expect(cardItem.getColor() == .standard)
        #expect(cardItem.color == CardColor.standard.rawValue)
    }

    @Test func colourIsStoredByRawValue() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card", color: .teal)
        #expect(cardItem.color == "teal")
        #expect(cardItem.getColor() == .teal)
    }

    @Test func unknownStoredColourFallsBackToStandard() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card", color: .red)
        cardItem.color = "chartreuse"
        #expect(cardItem.getColor() == .standard)
    }

    @Test func exportRoundTripKeepsColour() throws {
        let original = CardItem(timestamp: Date(timeIntervalSince1970: 0), code: "42", name: "Local Roast Coffee", color: .red)
        let data = try JSONEncoder().encode([CardItemDTO(from: original)])
        let imported = try JSONDecoder().decode([CardItemDTO].self, from: data)
        #expect(imported.first?.toCardItem().getColor() == .red)
    }

    @Test func exportWithoutColourStillImports() throws {
        let legacy = """
        [{"code":"42","name":"Local Roast Coffee","order":0,"timestamp":0,"type":"EAN-13"}]
        """
        let imported = try JSONDecoder().decode([CardItemDTO].self, from: Data(legacy.utf8))
        let card = try #require(imported.first?.toCardItem())
        #expect(card.getColor() == .standard)
        #expect(card.getBarcodeType() == .ean13)
    }

    @Test func identifiableConformance() {
        let cardItem = CardItem(timestamp: Date(), code: "1234567890", name: "Test Card")
        _ = cardItem.id
    }
}
