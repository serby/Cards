import Foundation

public extension CardLocation {
    static let sample = CardLocation(name: "Westway", latitude: 51.5203, longitude: -0.2094, radius: 150)

    static let samples: [CardLocation] = [
        .sample,
        CardLocation(name: "Portobello Market", latitude: 51.5154, longitude: -0.2052),
        CardLocation(name: "IKEA Wembley", latitude: 51.5560, longitude: -0.2796, radius: 400)
    ]
}

public extension CardSummary {
    static let samples: [CardSummary] = [
        CardSummary(
            id: "634004024987531",
            name: "Tesco Clubcard",
            color: .blue,
            proximity: CardProximity(placeName: "Tesco Express", distance: 0)
        ),
        CardSummary(id: "9780201379624", name: "Boots Advantage", color: .indigo),
        CardSummary(
            id: "1234567890128",
            name: "Costa Coffee",
            color: .red,
            proximity: CardProximity(placeName: "Costa Notting Hill", distance: 450)
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
}

public extension CardDetail {
    static let sample = CardDetail(
        id: "9780201379624",
        name: "Boots Advantage",
        code: "9780201379624",
        barcodeType: .ean13,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        color: .indigo,
        proximity: CardProximity(placeName: "Boots Westfield", distance: 320)
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
}

public extension CardDraft {
    static let sample = CardDraft(
        name: "Westway",
        code: "123ABC",
        barcodeType: .code128,
        color: .teal,
        locations: [.sample]
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
}
