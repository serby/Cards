import SwiftUI

@MainActor
let componentStories: [Story] = [
    barcodeStory,
    spinnerStory,
    cardRowStory,
    cardColorPickerStory,
    proximityLabelStory,
    cardLocationRowStory,
    scannerPlaceholderStory,
    cameraAccessOffStory
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

@MainActor
private let spinnerStory = Story(
    id: "spinner",
    title: "Spinner",
    section: "Components",
    knobs: [
        .toggle("Loading", true),
        .number("Grace time", 0, in: 0...2, step: 0.25)
    ],
    gallery: [
        (name: "Loading", view: AnyView(Spinner(isLoading: true))),
        (name: "Idle", view: AnyView(Spinner(isLoading: false))),
        (name: "Loading after 1s grace", view: AnyView(Spinner(isLoading: true, graceTime: 1)))
    ]
) { knobs in
    AnyView(
        Spinner(isLoading: knobs.bool("Loading"), graceTime: knobs.number("Grace time"))
    )
}

@MainActor
private let cardRowStory = Story(
    id: "card-row",
    title: "CardRowView",
    section: "Components",
    knobs: [
        .text("Name", "Tesco Clubcard"),
        .options("Colour", CardColor.allNames, CardColor.blue.rawValue)
    ] + ProximityKnobs.knobs(place: "Tesco Express"),
    gallery: [
        (
            name: "Short name, here",
            view: AnyView(CardRowView(card: CardSummary.samples[0]) {})
        ),
        (
            name: "Nearby",
            view: AnyView(CardRowView(card: CardSummary.samples[2]) {})
        ),
        (
            name: "Long name",
            view: AnyView(CardRowView(card: .longName) {})
        )
    ] + CardColor.allCases.map { color in
        let name = String(localized: color.displayName)
        return (
            name: name,
            view: AnyView(CardRowView(card: CardSummary(id: color.rawValue, name: name, color: color)) {})
        )
    }
) { knobs in
    AnyView(
        CardRowView(
            card: CardSummary(
                id: "story",
                name: knobs.string("Name"),
                color: .named(knobs.option("Colour")),
                proximity: knobs.proximity()
            )
        ) {}
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
                        Section {
                            CardColorPicker(selection: color)
                        } header: {
                            Text(verbatim: "Colour")
                        }
                    }
                }
                .frame(height: 200)
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
        .toggle("Shows place", false)
    ],
    gallery: [
        (name: "Here", view: AnyView(ProximityLabel(CardProximity(placeName: "Westway", distance: 0)))),
        (
            name: "Here, with place",
            view: AnyView(ProximityLabel(CardProximity(placeName: "Westway", distance: 0), showsPlace: true))
        ),
        (name: "Nearby", view: AnyView(ProximityLabel(CardProximity(placeName: "Westway", distance: 350)))),
        (
            name: "Far, with place",
            view: AnyView(ProximityLabel(CardProximity(placeName: "IKEA Wembley", distance: 6_800), showsPlace: true))
        )
    ]
) { knobs in
    AnyView(
        knobs.proximity(optional: false).map { proximity in
            ProximityLabel(proximity, showsPlace: knobs.bool("Shows place"))
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
    knobs: [
        .toggle("Camera access off", false)
    ],
    gallery: [
        (name: "Default", view: AnyView(ScannerPlaceholderView().frame(minHeight: 250))),
        (name: "Camera access off", view: AnyView(ScannerPlaceholderView(cameraAccessOff: true).frame(minHeight: 250)))
    ]
) { knobs in
    AnyView(
        // At least 250 pt, as in the card form, and taller when the message
        // needs it.
        ScannerPlaceholderView(cameraAccessOff: knobs.bool("Camera access off"))
            .frame(minHeight: 250)
            .padding()
    )
}

/// The message has no parameters; the story shows it on black, as the
/// scanner does, in a box that grows with it.
@MainActor
private let cameraAccessOffStory = Story(
    id: "camera-access-off-message",
    title: "CameraAccessOffMessage",
    section: "Components",
    knobs: [],
    gallery: [
        (name: "On the camera", view: AnyView(onTheCamera(CameraAccessOffMessage())))
    ]
) { _ in
    AnyView(onTheCamera(CameraAccessOffMessage()).padding())
}

@MainActor
private func onTheCamera(_ message: some View) -> some View {
    ZStack {
        Rectangle().fill(.black)
        message
    }
    .frame(minHeight: 250)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
