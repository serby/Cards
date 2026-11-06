import Foundation
import MapKit

public extension CardLocation {
    static let sample = CardLocation(name: "Westway", latitude: 51.5203, longitude: -0.2094, radius: 150)

    static let samples: [CardLocation] = [
        .sample,
        CardLocation(name: "Portobello Market", latitude: 51.5154, longitude: -0.2052),
        CardLocation(name: "IKEA Wembley", latitude: 51.5560, longitude: -0.2796, radius: 400)
    ]

    /// A region framing the sample location, for previews and stories.
    static let previewRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5203, longitude: -0.2094),
        latitudinalMeters: 1_200,
        longitudinalMeters: 1_200
    )
}

public extension CardSummary {
    static let samples: [CardSummary] = [
        CardSummary(
            id: "634004024987531",
            name: "Tesco Clubcard",
            color: .blue,
            proximity: CardProximity(placeName: "Tesco Express", distance: 0),
            symbol: "basket"
        ),
        CardSummary(id: "9780201379624", name: "Boots Advantage", color: .indigo, symbol: "cross.case"),
        CardSummary(
            id: "1234567890128",
            name: "Costa Coffee",
            color: .red,
            proximity: CardProximity(placeName: "Costa Notting Hill", distance: 450),
            symbol: "cup.and.saucer"
        ),
        CardSummary(id: "9988776655443", name: "Nectar", color: .purple),
        CardSummary(id: "5012345678900", name: "Sainsbury's Nectar", color: .orange),
        CardSummary(
            id: "7350053850019",
            name: "IKEA Family",
            color: .yellow,
            proximity: CardProximity(placeName: "IKEA Wembley", distance: 6_800)
        )
    ]

    static let longName = CardSummary(
        id: "0000000000001",
        name: "A loyalty card with an extremely long name that will certainly wrap"
    )

    /// The Symbol knob's choice for a card without one.
    static let noSymbol = "None"
    /// Symbols for the Symbol knob, with None first.
    static let storySymbols = [noSymbol, "basket", "cup.and.saucer", "dumbbell", "book", "fuelpump", "bag", "cross.case"]
}

public extension CardDetail {
    static let sample = CardDetail(
        id: "9780201379624",
        name: "Boots Advantage",
        code: "9780201379624",
        barcodeType: .ean13,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        color: .indigo,
        proximity: CardProximity(placeName: "Boots Westfield", distance: 320),
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
        id: "634004024987531",
        name: "Tesco Clubcard",
        code: "634004024987531",
        barcodeType: .code128,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        color: .blue,
        proximity: CardProximity(placeName: "Tesco Express", distance: 0),
        symbol: "basket"
    )
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
        name: "Westway",
        code: "123ABC",
        barcodeType: .code128,
        color: .teal,
        locations: [.sample],
        symbol: "figure.climbing"
    )
    static let empty = CardDraft()
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
        name: "Tesco Clubcard",
        code: "5012345678900",
        barcodeType: .ean13,
        color: .blue,
        proximity: CardProximity(placeName: "Tesco Express", distance: 120)
    )

    static let here = CardWidgetState(
        name: "Costa Coffee",
        code: "COSTA-88412",
        barcodeType: .code128,
        color: .red,
        proximity: CardProximity(placeName: "Costa Notting Hill", distance: 0)
    )

    static let qr = CardWidgetState(
        name: "Westway Climbing",
        code: "https://serby.net",
        barcodeType: .qrCode,
        color: .graphite,
        proximity: CardProximity(placeName: "Westway", distance: 350)
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
