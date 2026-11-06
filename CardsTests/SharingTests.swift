@testable import Cards
import Foundation
import SwiftUI
import Testing
import UIKit

/// Sharing a card as a link or an image, and reading a shared card back
/// (SHARE-1, SHARE-2, SHARE-3).
struct SharingTests {
    private let joesMarket = CardItem(
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        code: "482019375610284",
        name: "Joe's Market",
        barcodeType: .code128,
        order: 3,
        color: .blue,
        locations: [CardLocation(name: "Joe's Market Notting Hill", latitude: 51.5090, longitude: -0.1960, radius: 150)],
        notifiesOnArrival: false,
        symbol: "basket.fill",
        lastViewed: Date(timeIntervalSince1970: 1_780_000_000)
    )

    // MARK: The payload

    @Test func aCardRoundTripsThroughItsPayload() throws {
        let shared = SharedCard(joesMarket)
        let read = try #require(SharedCard(payload: shared.payload))
        #expect(read == shared)
        #expect(read.name == "Joe's Market")
        #expect(read.code == "482019375610284")
        #expect(read.barcodeType == .code128)
        #expect(read.color == .blue)
        #expect(read.symbol == "basket.fill")
        #expect(read.places == [SharedCard.Place(name: "Joe's Market Notting Hill", latitude: 51.5090, longitude: -0.1960, radius: 150)])
        #expect(read.notifiesOnArrival == false)
    }

    @Test(arguments: [
        SharedCard(name: "Website", code: "https://serby.net/a?b=c#d&e=%20", barcodeType: .qrCode, color: .custom(0x3399CC)),
        SharedCard(name: "Café ☕️", code: "Ünïcødé 123", barcodeType: .aztec, color: .standard, symbol: "cup.and.saucer.fill"),
        SharedCard(name: "No places", code: "1", notifiesOnArrival: true)
    ])
    func anyCardRoundTrips(_ card: SharedCard) {
        #expect(SharedCard(payload: card.payload) == card)
    }

    @Test func thePayloadIsBase64URLWithoutPadding() {
        // Lengths 1 to 3 more than a multiple of three would need padding in plain base64.
        for name in ["A", "AB", "ABC", "?>?>?>", "ÿÿÿ"] {
            let payload = SharedCard(name: name, code: "1").payload
            #expect(!payload.contains("+") && !payload.contains("/") && !payload.contains("="), "\(payload)")
            #expect(SharedCard(payload: payload)?.name == name)
        }
    }

    /// The link carries the card, not the sharer's history with it.
    @Test func thePayloadLeavesOutWhatIsTheSharers() throws {
        let json = try #require(Data(base64Encoded: base64(fromURL: SharedCard(joesMarket).payload)))
        let decoded = try JSONSerialization.jsonObject(with: json)
        let object = try #require(decoded as? [String: Any])
        #expect(Set(object.keys) == ["v", "name", "code", "type", "color", "symbol", "places", "notifiesOnArrival"])
        let place = try #require((object["places"] as? [[String: Any]])?.first)
        #expect(Set(place.keys) == ["name", "latitude", "longitude", "radius"])
        #expect(object["v"] as? Int == 1)
    }

    @Test(arguments: [
        "",
        "!!!!",
        "not base64 at all",
        "#",
        "AAAA",
        encode("not json"),
        encode("[1, 2, 3]"),
        encode("{}"),
        encode(#"{"v": 1, "name": "Gym"}"#),
        encode(#"{"v": 1, "code": "123"}"#),
        encode(#"{"v": "1", "name": "Gym", "code": "123"}"#),
        encode(#"{"name": "Gym", "code": "123"}"#)
    ])
    func garbageHoldsNoCard(_ payload: String) {
        #expect(SharedCard(payload: payload) == nil)
    }

    @Test func anEmptyFragmentHoldsNoCard() throws {
        let empty = try #require(URL(string: "https://cards.serby.net/add#"))
        let link = try #require(SharedCardLink(url: empty))
        #expect(link.payload.isEmpty)
        #expect(link.card == nil)
        let noHash = try #require(URL(string: "cards://cards/add"))
        let bare = try #require(SharedCardLink(url: noHash))
        #expect(bare.payload.isEmpty)
        #expect(bare.card == nil)
    }

    @Test func anOversizedPayloadHoldsNoCard() {
        let huge = SharedCard(name: String(repeating: "A", count: SharedCard.maximumPayloadLength), code: "1")
        #expect(huge.payload.count > SharedCard.maximumPayloadLength)
        #expect(SharedCard(payload: huge.payload) == nil)
        #expect(SharedCard(payload: String(repeating: "A", count: SharedCard.maximumPayloadLength + 1)) == nil)
    }

    @Test func unknownFieldsAreIgnored() throws {
        let payload = encode(#"{"v": 1, "name": "Gym", "code": "123", "future": {"x": [1, 2]}, "tier": "gold"}"#)
        let card = try #require(SharedCard(payload: payload))
        #expect(card == SharedCard(name: "Gym", code: "123"))
    }

    @Test func aNewerFormatHoldsNoCard() {
        #expect(SharedCard(payload: encode(#"{"v": 2, "name": "Gym", "code": "123"}"#)) == nil)
    }

    @Test func blankNamesAndCodesHoldNoCardAndTheRestIsTrimmed() throws {
        #expect(SharedCard(payload: encode(#"{"v": 1, "name": "  ", "code": "123"}"#)) == nil)
        #expect(SharedCard(payload: encode(#"{"v": 1, "name": "Gym", "code": "\n"}"#)) == nil)
        let card = try #require(SharedCard(payload: encode(#"{"v": 1, "name": " Gym ", "code": " 123\n"}"#)))
        #expect(card.name == "Gym")
        #expect(card.code == "123")
    }

    @Test func unknownTypesColoursAndEmptySymbolsFallBack() throws {
        let payload = encode(#"{"v": 1, "name": "Gym", "code": "1", "type": "Hologram", "color": "ultraviolet", "symbol": ""}"#)
        let card = try #require(SharedCard(payload: payload))
        #expect(card.barcodeType == .code128)
        #expect(card.color == .standard)
        #expect(card.symbol == nil)
        #expect(card.notifiesOnArrival)
    }

    @Test func placesOffTheMapAreDroppedAndRadiiKeptInRange() throws {
        let payload = encode("""
        {"v": 1, "name": "Gym", "code": "1", "places": [
            {"name": "Small", "latitude": 51.5, "longitude": -0.2, "radius": 1},
            {"name": "Huge", "latitude": 51.5, "longitude": -0.2, "radius": 1e9},
            {"name": "Nowhere", "latitude": 95, "longitude": 0, "radius": 200},
            {"name": "Elsewhere", "latitude": 0, "longitude": -181, "radius": 200}
        ]}
        """)
        let card = try #require(SharedCard(payload: payload))
        #expect(card.places.map(\.name) == ["Small", "Huge"])
        #expect(card.places.map(\.radius) == [CardLocation.radiusRange.lowerBound, CardLocation.radiusRange.upperBound])
    }

    // MARK: Links

    @Test func shareLinksPointAtTheWebsiteWithTheCardAfterTheHash() throws {
        let link = SharedCardLink(card: SharedCard(joesMarket))
        let payload = SharedCard(joesMarket).payload
        #expect(try #require(link.url).absoluteString == "https://cards.serby.net/add#\(payload)")
        #expect(try #require(link.appURL).absoluteString == "cards://cards/add#\(payload)")
    }

    @Test func bothFormsOfShareLinkAreRead() throws {
        let link = SharedCardLink(card: SharedCard(joesMarket))
        for url in [try #require(link.url), try #require(link.appURL)] {
            let read = try #require(SharedCardLink(url: url))
            #expect(read == link)
            #expect(read.card == SharedCard(joesMarket))
        }
        let shouting = try #require(URL(string: "HTTPS://Cards.Serby.NET/add#\(link.payload)"))
        #expect(SharedCardLink(url: shouting) == link)
    }

    @Test(arguments: [
        "https://cards.serby.net",
        "https://cards.serby.net/#abc",
        "https://cards.serby.net/privacy.html#abc",
        "https://cards.serby.net/add/more#abc",
        "https://cards.serby.net/add.html#abc",
        "http://cards.serby.net/add#abc",
        "https://example.com/add#abc",
        "https://serby.net/add#abc",
        "cards://cards/card/123",
        "cards://cards/new",
        "cards://other/add#abc",
        "other://cards/add#abc"
    ])
    func otherLinksAreNotShareLinks(_ string: String) throws {
        let url = try #require(URL(string: string))
        #expect(SharedCardLink(url: url) == nil)
    }

    // MARK: Adding a shared card

    @Test func aSharedCardWhoseCodeIsAlreadyHereIsDetected() {
        let existing = [CardItem(code: " 482019375610284 ", name: "My Joe's Market", order: 0)]
        let result = SharedCard(joesMarket).importResult(existing: existing, addedAt: .now)
        #expect(result.alreadyHere == 1)
        #expect(result.added.isEmpty)
    }

    @Test func aNewSharedCardIsAddedAtTheEndWithFreshPlaces() throws {
        let existing = [CardItem(code: "a", name: "A", order: 0), CardItem(code: "b", name: "B", order: 4)]
        let added = Date(timeIntervalSince1970: 1_790_000_000)
        let result = SharedCard(joesMarket).importResult(existing: existing, addedAt: added)
        let card = try #require(result.added.first)
        #expect(result.added.count == 1)
        #expect(card.order == 5)
        #expect(card.timestamp == added)
        #expect(card.lastViewed == nil)
        #expect(card.code == joesMarket.code)
        #expect(card.symbol == "basket.fill")
        #expect(card.getColor() == .blue)
        #expect(card.notifiesOnArrival == false)
        #expect(card.locations.map(\.name) == ["Joe's Market Notting Hill"])
        #expect(card.locations.first?.id != joesMarket.locations.first?.id)
    }

    /// The sheet's Add Card and Open Card buttons put the system background's
    /// colour, white or black, on the accent.
    @Test func theSheetsButtonTextIsReadableOnTheAccent() {
        #expect(WCAG.contrast(0xFFFFFF, Color.accentLightRGB) >= WCAG.minimumTextContrast)
        #expect(WCAG.contrast(0x000000, Color.accentDarkRGB) >= WCAG.minimumTextContrast)
    }

    // MARK: The image

    @Test(arguments: [
        ("Green Leaf Pharmacy", "Green Leaf Pharmacy.png"),
        ("Gym / Pool: 24h", "Gym - Pool- 24h.png"),
        ("  ", "Card.png"),
        ("...", "Card.png"),
        ("Two\nlines", "Two-lines.png")
    ])
    func imageFileNamesComeFromTheCardsName(_ name: String, _ fileName: String) {
        #expect(CardImage.fileName(for: name) == fileName)
    }

    /// Also writes the picture to `CARDS_SHARE_IMAGE_DIR` when it is set, to look at.
    @Test @MainActor func theSharedImageIsTheFaceAtThreeTimesScale() throws {
        let png = try #require(CardShareImage.png(of: .sample))
        let image = try #require(UIImage(data: png))
        #expect(image.size.width * image.scale == CardShareImage.width * CardShareImage.scale)
        #expect(image.size.height > image.size.width / 2)
        if let folder = ProcessInfo.processInfo.environment["CARDS_SHARE_IMAGE_DIR"] {
            try png.write(to: URL(filePath: folder).appending(path: CardImage.fileName(for: CardDetail.sample.name)))
        }
    }
}

/// `json` as a share link payload.
private func encode(_ json: String) -> String {
    Data(json.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

/// Plain base64, with its padding, from base64url.
private func base64(fromURL payload: String) -> String {
    let plain = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    return plain + String(repeating: "=", count: (4 - plain.count % 4) % 4)
}
