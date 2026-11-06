import Foundation
import MapKit

public extension CardLocation {
    static let sample = CardLocation(name: "Boulder Barn", latitude: 51.5203, longitude: -0.2094, radius: 150)

    static let samples: [CardLocation] = [
        .sample,
        CardLocation(name: "Portobello Market", latitude: 51.5154, longitude: -0.2052),
        CardLocation(name: "Nordic Nest Wembley", latitude: 51.5560, longitude: -0.2796, radius: 400)
    ]

    /// A region framing the sample location, for previews and stories.
    static let previewRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5203, longitude: -0.2094),
        latitudinalMeters: 1_200,
        longitudinalMeters: 1_200
    )

    /// Joe's Market's places round Notting Hill, in the card's order, which is
    /// not the order of their distance from `CLLocation.sampleHere` (PLACE-9).
    static let joesMarket: [CardLocation] = [
        CardLocation(name: "Joe's Market Notting Hill", latitude: 51.5090, longitude: -0.1960, radius: 150),
        CardLocation(name: "Joe's Market Kensington", latitude: 51.4990, longitude: -0.1990),
        CardLocation(name: "Joe's Market Holland Park", latitude: 51.5075, longitude: -0.2058, radius: 150),
        CardLocation(name: "Joe's Market Earl's Court", latitude: 51.4920, longitude: -0.1934),
        CardLocation(name: "Joe's Market Bayswater", latitude: 51.5122, longitude: -0.1879, radius: 150),
        CardLocation(name: "Joe's Market Shepherd's Bush", latitude: 51.5046, longitude: -0.2187),
        CardLocation(name: "Joe's Market Ladbroke Grove", latitude: 51.5172, longitude: -0.2107, radius: 150)
    ]
}

public extension CLLocation {
    /// Notting Hill Gate, inside Joe's Market Notting Hill: where you are in the
    /// stories and previews that measure distances to the sample places.
    static let sampleHere = CLLocation(latitude: 51.5091, longitude: -0.1963)
}

public extension CardSummary {
    static let samples: [CardSummary] = [
        CardSummary(
            id: "482019375610284",
            name: "Joe's Market",
            color: .blue,
            proximity: CardProximity(placeName: "Joe's Market Notting Hill", distance: 0),
            symbol: "basket"
        ),
        CardSummary(id: "9780201379624", name: "Green Leaf Pharmacy", color: .indigo, symbol: "cross.case"),
        CardSummary(
            id: "1234567890128",
            name: "Local Roast Coffee",
            color: .red,
            proximity: CardProximity(placeName: "Local Roast Notting Hill", distance: 450),
            symbol: "cup.and.saucer"
        ),
        CardSummary(id: "9988776655443", name: "Honeycomb Rewards", color: .purple),
        CardSummary(id: "5012345678900", name: "Ladbroke Library", color: .orange),
        CardSummary(
            id: "2093847561024",
            name: "Nordic Nest Home",
            color: .yellow,
            proximity: CardProximity(placeName: "Nordic Nest Wembley", distance: 6_800)
        )
    ]

    static let longName = CardSummary(
        id: "0000000000001",
        name: "A loyalty card with an extremely long name that will certainly wrap",
        color: .yellow,
        proximity: CardProximity(placeName: "Long Way", distance: 1_800)
    )

    /// The Symbol knob's choice for a card without one.
    static let noSymbol = "None"
    /// Symbols for the Symbol knob, with None first.
    static let storySymbols = [noSymbol, "basket", "cup.and.saucer", "dumbbell", "book", "fuelpump", "bag", "cross.case"]
}

public extension CardDetail {
    static let sample = CardDetail(
        id: "9780201379624",
        name: "Green Leaf Pharmacy",
        code: "9780201379624",
        barcodeType: .ean13,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        color: .indigo,
        proximity: CardProximity(placeName: "Green Leaf Shepherd's Bush", distance: 320),
        symbol: "cross.case.fill"
    )

    static let qr = CardDetail(
        id: "https://serby.net",
        name: "Website",
        code: "https://serby.net",
        barcodeType: .qrCode,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        color: .graphite
    )

    static let invalidCode = CardDetail(
        id: "not-a-valid-ean",
        name: "Broken Card",
        code: "not-a-valid-ean",
        barcodeType: .ean13,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )

    /// The first sample card, as the list shows it in full where you are (SET-3).
    static let here = CardDetail(
        id: "482019375610284",
        name: "Joe's Market",
        code: "482019375610284",
        barcodeType: .code128,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        color: .blue,
        proximity: CardProximity(placeName: "Joe's Market Notting Hill", distance: 0),
        symbol: "basket"
    )
}

/// Joe's Market with several places, for the card screen's list of them (PLACE-9).
public extension CardDetail {
    /// Joe's Market with its first `places` sample places, measured from `location`.
    static func joesMarket(places: Int, near location: CLLocation? = .sampleHere) -> CardDetail {
        let locations = Array(CardLocation.joesMarket.prefix(places))
        return CardDetail(
            id: "482019375610284",
            name: "Joe's Market",
            code: "482019375610284",
            barcodeType: .code128,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            color: .blue,
            places: CardPlaces(locations, near: location),
            proximity: locations.proximity(to: location)
        )
    }

    /// Two places, as Joe's Market has in the screenshot cards.
    static let twoPlaces = joesMarket(places: 2)
    /// Seven places: the list shows the nearest five and says there are 2 more.
    static let sevenPlaces = joesMarket(places: 7)
    /// Seven places while where you are is unknown: the first five in the card's order.
    static let placesWithoutLocation = joesMarket(places: 7, near: nil)
}

public extension CardShare {
    /// The share menu's link and picture for `card`, made as the card screen makes them.
    @MainActor
    static func sample(for card: CardDetail) -> CardShare {
        let shared = SharedCard(name: card.name, code: card.code, barcodeType: card.barcodeType, color: card.color, symbol: card.symbol)
        return CardShare(
            link: SharedCardLink(card: shared).url ?? URL(fileURLWithPath: "/"),
            image: CardImage(cardName: card.name) { CardShareImage.png(of: card) }
        )
    }
}

public extension CardDraft {
    static let sample = CardDraft(
        name: "Boulder Barn",
        code: "123ABC",
        barcodeType: .code128,
        color: .teal,
        locations: [.sample],
        symbol: "figure.climbing"
    )
    static let empty = CardDraft()
}

public extension FoundBarcode {
    /// What a membership PDF might hold: a QR code, a strip barcode and a
    /// till barcode, each a different type.
    static let samples: [FoundBarcode] = [
        FoundBarcode(code: "BOULDERBARN-10442", type: .qrCode),
        FoundBarcode(code: "LRC-0042-7781", type: .code128),
        FoundBarcode(code: "2900417730126", type: .ean13)
    ]
    /// A QR code holding a web address, longer than a row can show in full.
    static let longCode = FoundBarcode(
        code: "https://boulderbarn.example/visit/10442?pass=2026-11-14-ANNUAL-PEAK-AND-OFFPEAK",
        type: .qrCode
    )
}

public extension SettingsState {
    static let sample = SettingsState(
        appVersion: "1.1",
        appBuild: "42",
        authorName: "Paul Serby",
        authorURL: URL(string: "https://github.com/serby"),
        cardCount: 6
    )

    static let noCards = SettingsState(
        appVersion: "1.1",
        appBuild: "42",
        authorName: "Paul Serby",
        authorURL: URL(string: "https://github.com/serby"),
        cardCount: 0
    )

    static let withNotificationsBlocked = SettingsState(
        appVersion: "1.1",
        appBuild: "42",
        authorName: "Paul Serby",
        authorURL: URL(string: "https://github.com/serby"),
        cardCount: 6,
        notificationsBlocked: true
    )
}

public extension CardWidgetState {
    static let sample = CardWidgetState(
        name: "Joe's Market",
        code: "5012345678900",
        barcodeType: .ean13,
        color: .blue,
        proximity: CardProximity(placeName: "Joe's Market Notting Hill", distance: 120)
    )

    static let here = CardWidgetState(
        name: "Local Roast Coffee",
        code: "ROAST-88412",
        barcodeType: .code128,
        color: .red,
        proximity: CardProximity(placeName: "Local Roast Notting Hill", distance: 0)
    )

    static let qr = CardWidgetState(
        name: "Boulder Barn Climbing",
        code: "https://serby.net",
        barcodeType: .qrCode,
        color: .graphite,
        proximity: CardProximity(placeName: "Boulder Barn", distance: 350)
    )

    static let noLocation = CardWidgetState(name: "Library Card", code: "ABC-1234", barcodeType: .code128)

    static let invalidCode = CardWidgetState(name: "Broken Card", code: "not-a-valid-ean", barcodeType: .ean13, color: .purple)
}

public extension ChangelogVersion {
    static let samples: [ChangelogVersion] = [
        ChangelogVersion(
            version: "1.3",
            date: nil,
            changes: [
                ChangelogChange(kind: .new, text: "Add the Home Screen widget to see the barcode of the card for where you are."),
                ChangelogChange(kind: .new, text: "Give each card a colour from 23, or pick any colour you like."),
                ChangelogChange(kind: .improved, text: "Cards show their full colour in the list."),
                ChangelogChange(kind: .fixed, text: "The message for a code that cannot be drawn is readable in dark mode.")
            ]
        ),
        ChangelogVersion(
            version: "1.1",
            date: Date(timeIntervalSince1970: 1_767_268_800),
            changes: [
                ChangelogChange(kind: .new, text: "Scan a barcode with the camera to add a card."),
                ChangelogChange(kind: .improved, text: "The screen brightens when you open a card.")
            ]
        )
    ]
}
