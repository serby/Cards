import CoreLocation
import Foundation

/// Made-up cards for the watch's previews (docs/LANGUAGE.md). Their barcodes
/// are module grids the iPhone made for these codes (`BarcodeModules(code:type:)`),
/// written out here as rows of 1 for dark and 0 for light, since the watch
/// cannot draw a barcode itself. Never in a release build.
extension WatchCard {
    static let joesMarketNottingHill = CardLocation(name: "Joe's Market Notting Hill", latitude: 51.5090, longitude: -0.1960, radius: 150)
    static let boulderBarnPlace = CardLocation(name: "Boulder Barn", latitude: 51.5203, longitude: -0.2094, radius: 150)
    /// Inside Boulder Barn's circle.
    static let atBoulderBarn = CLLocation(latitude: 51.5204, longitude: -0.2094)

    /// EAN-13 1234567890128: guard, six left digits, centre, six right digits, guard.
    static let joesMarket = WatchCard(
        code: "1234567890128",
        name: "Joe's Market",
        barcodeType: .ean13,
        color: .blue,
        icon: "cart.fill",
        locations: [joesMarketNottingHill],
        modules: grid([
            "101" + "0010011" + "0111101" + "0011101" + "0110001" + "0000101" + "0010001" + "01010"
                + "1001000" + "1110100" + "1110010" + "1100110" + "1101100" + "1001000" + "101"
        ])
    )

    static let boulderBarn = WatchCard(
        code: "BOULDERBARN-10442",
        name: "Boulder Barn Climbing",
        barcodeType: .qrCode,
        color: .graphite,
        icon: "figure.climbing",
        locations: [boulderBarnPlace],
        modules: grid(boulderQRCode)
    )

    /// Code 128 9988776655443, a Default card with no places.
    static let honeycombRewards = WatchCard(
        code: "9988776655443",
        name: "Honeycomb Rewards",
        barcodeType: .code128,
        color: .standard,
        modules: grid(["110100111001011101111011110010010111101110101001000011011101000110100011011101110101111011001011100100110001001100011101011"])
    )

    /// Fourteen digits, one too many for EAN-13, so it cannot be drawn.
    static let ladbrokeLibrary = WatchCard(code: "50123456789012", name: "Ladbroke Library", barcodeType: .ean13, color: .orange, modules: nil)

    static let samples: [WatchCard] = [joesMarket, boulderBarn, honeycombRewards, ladbrokeLibrary]

    private static func grid(_ rows: [String]) -> BarcodeModules? {
        BarcodeModules(dark: rows.map { row in row.map { $0 == "1" } })
    }

    /// QR Code BOULDERBARN-10442, 21 modules a side.
    private static let boulderQRCode = [
        "111111101111001111111",
        "100000101100001000001",
        "101110101101101011101",
        "101110100010001011101",
        "101110101010101011101",
        "100000100001101000001",
        "111111101010101111111",
        "000000000011100000000",
        "100111111000110010111",
        "001101001110111010010",
        "101010101000000111011",
        "111101000101001111000",
        "011011100010011000011",
        "000000001010111101110",
        "111111101000110000011",
        "100000101010100110001",
        "101110101100110100100",
        "101110101001110110100",
        "101110100111111010111",
        "100000100010101011010",
        "111111101011000010010"
    ]
}

extension WatchCardSummary {
    /// The sample cards as the list shows them, at Notting Hill Gate: inside
    /// Joe's Market Notting Hill and a mile and a half from Boulder Barn.
    static let samples: [WatchCardSummary] = WatchCard.samples.map { card in
        WatchCardSummary(
            id: card.code,
            name: card.name,
            color: card.color,
            icon: card.icon,
            proximity: card.proximity(to: CLLocation(latitude: 51.5091, longitude: -0.1963))
        )
    }
}

extension WatchCards {
    /// Cards that are simply there, kept nowhere.
    static func preview(_ cards: [WatchCard]) -> WatchCards {
        let kept = KeptSnapshot(sentAt: .now, snapshot: WatchSnapshot(cards: cards, distanceUnits: .automatic))
        return WatchCards(file: WatchSnapshotFile(read: { cards.isEmpty ? nil : kept }, write: { _ in }))
    }
}

extension WatchLocation {
    /// Always `location`, at once.
    static func fixed(_ location: CLLocation?) -> Self {
        Self { location }
    }
}
