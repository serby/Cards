import SwiftUI

@MainActor
let componentStories: [Story] = [
    barcodeStory,
    cardTileStory,
    cardColorPickerStory,
    proximityLabelStory,
    cardLocationRowStory,
    cardWidgetStory,
    cameraUnavailableStory,
    scannerPlaceholderStory,
    cardFaceStory,
    cardSymbolPickerStory
]

@MainActor
private let barcodeStory = Story(
    id: "barcode-view",
    title: "BarcodeView",
    section: "Components",
    knobs: [
        .text("Code", "5012345678900"),
        .options("Type", BarcodeType.allNames, BarcodeType.ean13.rawValue)
    ],
    gallery: BarcodeType.allCases.map { type in
        (
            name: type.rawValue,
            view: AnyView(
                BarcodeView(barcodeString: SampleCode.valid(for: type), barcodeType: type)
                    .frame(height: 140)
            )
        )
    } + [
        (
            name: "Invalid code",
            view: AnyView(
                BarcodeView(barcodeString: "nope", barcodeType: .ean13)
                    .frame(height: 140)
            )
        )
    ]
) { knobs in
    AnyView(
        BarcodeView(
            barcodeString: knobs.string("Code"),
            barcodeType: .named(knobs.option("Type"))
        )
        .padding()
    )
}

/// A tile at the width it has in the grid on an iPhone.
@MainActor
private func tile(_ card: CardSummary, isDropTarget: Bool = false) -> AnyView {
    AnyView(
        CardTileView(card: card, isDropTarget: isDropTarget, onTap: {})
            .frame(width: 180)
    )
}

@MainActor
private let cardTileStory = Story(
    id: "card-tile",
    title: "CardTileView",
    section: "Components",
    knobs: [
        .text("Name", "Joe's Market"),
        .options("Colour", CardColor.allNames, CardColor.blue.rawValue),
        .options("Symbol", CardSummary.storySymbols, "basket"),
        .number("Width", 180, in: 120...400, step: 10),
        .toggle("Drop target", false)
    ] + ProximityKnobs.knobs(place: "Joe's Market Notting Hill", distance: 0),
    gallery: [
        (name: "Here, with a symbol", view: tile(CardSummary.samples[0])),
        (name: "Nearby", view: tile(CardSummary.samples[2])),
        (name: "No place or symbol", view: tile(CardSummary.samples[3])),
        (name: "Long name", view: tile(.longName)),
        (name: "Drop target", view: tile(CardSummary.samples[1], isDropTarget: true))
    ] + CardColor.allCases.map { color in
        (name: color.displayName, view: tile(CardSummary(id: color.rawValue, name: color.displayName, color: color)))
    }
) { knobs in
    let symbol = knobs.option("Symbol")
    return AnyView(
        CardTileView(
            card: CardSummary(
                id: "story",
                name: knobs.string("Name"),
                color: .named(knobs.option("Colour")),
                proximity: knobs.proximity(),
                symbol: symbol == CardSummary.noSymbol ? nil : symbol
            ),
            isDropTarget: knobs.bool("Drop target"),
            onTap: {}
        )
        .frame(width: knobs.number("Width"))
        .padding()
    )
}

@MainActor
private let cardColorPickerStory = Story(
    id: "card-color-picker",
    title: "CardColorPicker",
    section: "Components",
    knobs: [
        .options("Colour", CardColor.allNames, CardColor.blue.rawValue)
    ],
    gallery: [
        (
            name: "In a form",
            view: AnyView(
                Stateful(CardColor.teal) { color in
                    Form {
                        Section("Colour") {
                            CardColorPicker(selection: color)
                        }
                    }
                }
                .frame(height: 280)
            )
        ),
        (
            name: "Custom colour chosen",
            view: AnyView(
                Stateful(CardColor.custom(0x3399CC)) { color in
                    Form {
                        Section("Colour") {
                            CardColorPicker(selection: color)
                        }
                    }
                }
                .frame(height: 280)
            )
        )
    ]
) { knobs in
    AnyView(
        CardColorPicker(
            selection: Binding(
                get: { .named(knobs.option("Colour")) },
                set: { knobs.select($0.rawValue, for: "Colour") }
            )
        )
        .padding()
    )
}

@MainActor
private let proximityLabelStory = Story(
    id: "proximity-label",
    title: "ProximityLabel",
    section: "Components",
    knobs: ProximityKnobs.knobs(optional: false) + [
        .toggle("Shows place", false),
        .toggle("Highlights here", true)
    ],
    gallery: [
        (name: "Here", view: AnyView(ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 0)))),
        (
            name: "Here, with place",
            view: AnyView(ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 0), showsPlace: true))
        ),
        (name: "Nearby", view: AnyView(ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 350)))),
        (
            name: "Far, with place",
            view: AnyView(ProximityLabel(CardProximity(placeName: "Nordic Nest Wembley", distance: 6_800), showsPlace: true))
        )
    ]
) { knobs in
    AnyView(
        knobs.proximity(optional: false).map { proximity in
            ProximityLabel(proximity, showsPlace: knobs.bool("Shows place"), highlightsHere: knobs.bool("Highlights here"))
                .padding()
        }
    )
}

@MainActor
private let cardLocationRowStory = Story(
    id: "card-location-row",
    title: "CardLocationRow",
    section: "Components",
    knobs: [
        .text("Name", CardLocation.sample.name),
        .number("Radius (m)", CardLocation.sample.radius, in: 50...1_000, step: 25)
    ],
    gallery: CardLocation.samples.map { location in
        (name: location.name, view: AnyView(List { CardLocationRow(location) }.frame(height: 90)))
    }
) { knobs in
    let location = CardLocation(
        name: knobs.string("Name"),
        latitude: CardLocation.sample.latitude,
        longitude: CardLocation.sample.longitude,
        radius: knobs.number("Radius (m)")
    )
    return AnyView(
        List { CardLocationRow(location) }
    )
}

@MainActor
private let scannerPlaceholderStory = Story(
    id: "scanner-placeholder",
    title: "ScannerPlaceholderView",
    section: "Components",
    knobs: [],
    gallery: [
        (name: "Default", view: AnyView(ScannerPlaceholderView().frame(height: 250)))
    ]
) { _ in
    AnyView(
        ScannerPlaceholderView()
            .frame(height: 250)
            .padding()
    )
}

@MainActor
private let cardWidgetStory = Story(
    id: "card-widget",
    title: "CardWidgetView",
    section: "Components",
    knobs: [
        .toggle("Has card", true),
        .text("Name", CardWidgetState.sample.name),
        .text("Code", CardWidgetState.sample.code),
        .options("Type", BarcodeType.allNames, BarcodeType.ean13.rawValue),
        .options("Colour", CardColor.allNames, CardColor.blue.rawValue)
    ] + ProximityKnobs.knobs(place: "Joe's Market Notting Hill", distance: 120),
    gallery: [
        (name: "Nearby", view: AnyView(CardWidgetView(card: .sample).widgetPreviewFrame(.blue))),
        (name: "Here", view: AnyView(CardWidgetView(card: .here).widgetPreviewFrame(.red))),
        (name: "QR code", view: AnyView(CardWidgetView(card: .qr).widgetPreviewFrame(.graphite))),
        (name: "No location", view: AnyView(CardWidgetView(card: .noLocation).widgetPreviewFrame(.standard))),
        (name: "Invalid code", view: AnyView(CardWidgetView(card: .invalidCode).widgetPreviewFrame(.purple))),
        (name: "No cards", view: AnyView(CardWidgetView(card: nil).widgetPreviewFrame(.standard)))
    ]
) { knobs in
    let color = CardColor.named(knobs.option("Colour"))
    let card = CardWidgetState(
        name: knobs.string("Name"),
        code: knobs.string("Code"),
        barcodeType: .named(knobs.option("Type")),
        color: color,
        proximity: knobs.proximity()
    )
    return AnyView(
        CardWidgetView(card: knobs.bool("Has card") ? card : nil)
            .widgetPreviewFrame(knobs.bool("Has card") ? color : .standard)
            .padding()
    )
}

@MainActor
private let cameraUnavailableStory = Story(
    id: "camera-unavailable",
    title: "CameraUnavailableView",
    section: "Components",
    knobs: [
        .options("Reason", ["denied", "unavailable"], "denied")
    ],
    gallery: [
        (name: "Access off", view: AnyView(CameraUnavailableView(reason: .denied).frame(height: 250))),
        (name: "No camera", view: AnyView(CameraUnavailableView(reason: .unavailable).frame(height: 250)))
    ]
) { knobs in
    AnyView(
        CameraUnavailableView(reason: knobs.option("Reason") == "denied" ? .denied : .unavailable)
            .frame(height: 250)
            .padding()
    )
}

@MainActor
private let cardFaceStory = Story(
    id: "card-face",
    title: "CardFaceView",
    section: "Components",
    knobs: [
        .text("Name", CardDetail.sample.name),
        .text("Code", CardDetail.sample.code),
        .options("Type", BarcodeType.allNames, BarcodeType.ean13.rawValue),
        .options("Colour", CardColor.allNames, CardDetail.sample.color.rawValue),
        SymbolKnob.knob(CardDetail.sample.symbol),
        .toggle("Copy button", true)
    ] + ProximityKnobs.knobs(place: "Green Leaf Shepherd's Bush", distance: 320) + [
        .toggle("Panel below", false)
    ],
    gallery: [CardDetail.sample, .qr, .invalidCode].map { card in
        (name: card.name, view: AnyView(CardFaceView(card: card).padding()))
    }
) { knobs in
    let card = CardDetail(
        id: "story",
        name: knobs.string("Name"),
        code: knobs.string("Code"),
        barcodeType: .named(knobs.option("Type")),
        timestamp: Date.now,
        color: .named(knobs.option("Colour")),
        proximity: knobs.proximity(),
        symbol: knobs.symbol
    )
    return AnyView(
        CardFaceView(card: card, accessoryWidth: knobs.bool("Copy button") ? 44 : 0) {
            if knobs.bool("Copy button") {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(CardPanel.secondaryInk)
                    .frame(width: 44, height: 44)
            }
        } footer: {
            // The card screen puts its places here (PLACE-9).
            if knobs.bool("Panel below") {
                Text("A panel below the number")
                    .font(.subheadline)
                    .foregroundStyle(CardPanel.ink)
                    .cardPanel()
            }
        }
        .padding()
    )
}
