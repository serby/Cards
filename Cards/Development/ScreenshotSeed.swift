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
}
