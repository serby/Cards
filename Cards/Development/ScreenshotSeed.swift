import CoreLocation
import Foundation
import SwiftData

/// The cards the App Store screenshots show. The screenshot UI test launches
/// the app with -screenshotSeed, and DevelopmentHooks inserts these and puts the
/// user at `location`, so every run shows the same distances.
enum ScreenshotSeed {
    /// Notting Hill Gate, inside the Joe's Market Notting Hill circle.
    static let location = CLLocation(latitude: 51.5091, longitude: -0.1963)
    /// When every card was added, so the detail screen shows the same date on every run.
    static let added = Date(timeIntervalSince1970: 1_780_000_000)

    @MainActor
    static func insert(into context: ModelContext) throws {
        let cards = [
            CardItem(
                timestamp: added,
                code: "482019375610284",
                name: "Joe's Market",
                barcodeType: .code128,
                order: 0,
                color: .blue,
                locations: [
                    CardLocation(name: "Joe's Market Notting Hill", latitude: 51.5090, longitude: -0.1960, radius: 150),
                    CardLocation(name: "Joe's Market Kensington", latitude: 51.4990, longitude: -0.1990, radius: 200)
                ]
            ),
            CardItem(
                timestamp: added,
                code: "1234567890128",
                name: "Local Roast Coffee",
                barcodeType: .ean13,
                order: 1,
                color: .red,
                locations: [CardLocation(name: "Local Roast Portobello", latitude: 51.5150, longitude: -0.2040, radius: 100)]
            ),
            CardItem(
                timestamp: added,
                code: "9780201379624",
                name: "Green Leaf Pharmacy",
                barcodeType: .ean13,
                order: 2,
                color: .indigo,
                locations: [CardLocation(name: "Green Leaf Shepherd's Bush", latitude: 51.5072, longitude: -0.2213)]
            ),
            CardItem(
                timestamp: added,
                code: "https://serby.net",
                name: "Boulder Barn Climbing",
                barcodeType: .qrCode,
                order: 3,
                color: .graphite,
                locations: [CardLocation(name: "Boulder Barn", latitude: 51.5203, longitude: -0.2094, radius: 150)]
            ),
            CardItem(timestamp: added, code: "9988776655443", name: "Honeycomb Rewards", barcodeType: .code128, order: 4, color: .purple),
            CardItem(
                timestamp: added,
                code: "2093847561024",
                name: "Nordic Nest Home",
                barcodeType: .code128,
                order: 5,
                color: .yellow,
                locations: [CardLocation(name: "Nordic Nest Wembley", latitude: 51.5560, longitude: -0.2796, radius: 400)]
            )
        ]
        cards.forEach(context.insert)
        try context.save()
    }

    /// Ten more made-up cards after the six, for the App Store image of a full
    /// grid (-manyScreenshotCards), none with a place.
    @MainActor
    static func insertMany(into context: ModelContext) throws {
        let more: [(name: String, color: CardColor)] = [
            ("Paper Lantern Books", .orange),
            ("Riverside Swim Club", .teal),
            ("Little Fern Florist", .green),
            ("Copper Kettle Bakery", .red),
            ("Northside Cinema", .indigo),
            ("Brightwell Pharmacy", .blue),
            ("Tidal Yoga Studio", .pink),
            ("Old Mill Garden Centre", .green),
            ("Harbour Fish Bar", .teal),
            ("Kite Hill Library", .graphite)
        ]
        for (offset, card) in more.enumerated() {
            let code = String(4_006_381_333_931 + offset * 7)
            context.insert(CardItem(timestamp: added, code: code, name: card.name, barcodeType: .code128, order: 6 + offset, color: card.color))
        }
        try context.save()
    }

    /// The code of the card `insertCardThatCannotDraw` adds, fourteen digits,
    /// one too many for EAN-13, so its screen shows the failure message.
    static let codeThatCannotDraw = "50123456789012"

    /// Adds Ladbroke Library, a card whose barcode cannot be drawn, first in the
    /// list, for the UI tests that look at that screen
    /// (`-cardThatCannotDraw`). Typing a bad code into the edit form instead
    /// needs the keyboard, which XCUITest on iOS 18.1 did not get.
    @MainActor
    static func insertCardThatCannotDraw(into context: ModelContext) throws {
        context.insert(CardItem(timestamp: added, code: codeThatCannotDraw, name: "Ladbroke Library", barcodeType: .ean13, order: -1, color: .orange))
        try context.save()
    }
}
