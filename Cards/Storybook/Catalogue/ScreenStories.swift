#if DEBUG
import MapKit
import SwiftUI

@MainActor
let screenStories: [Story] = [
    cardListStory,
    cardDetailStory,
    cardEditStory,
    locationPickerStory,
    settingsStory,
    importCardsStory
]

private struct EditCardStory: View {
    @State private var draft: CardDraft
    private let title: String
    private let showsScanner: Bool

    init(draft: CardDraft, title: String, showsScanner: Bool) {
        _draft = State(initialValue: draft)
        self.title = title
        self.showsScanner = showsScanner
    }

    var body: some View {
        CardEditView(draft: $draft, showsScanner: showsScanner) {
            ScannerPlaceholderView()
        }
        .navigationTitle(title)
    }
}

/// A screen that is pushed onto a navigation stack in the app.
@MainActor
private func pushed<Content: View>(@ViewBuilder _ content: () -> Content) -> AnyView {
    AnyView(NavigationStack(root: content))
}

/// A screen that brings its own NavigationStack, such as a sheet.
@MainActor
private func standalone<Content: View>(@ViewBuilder _ content: () -> Content) -> AnyView {
    AnyView(content())
}

@MainActor
private let cardListStory = Story(
    id: "card-list",
    title: "CardListView",
    section: "Screens",
    galleryLayout: .oneAtATime,
    knobs: [
        .number("Cards", 6, in: 0...Double(CardSummary.samples.count), step: 1),
        .toggle("Colours", true),
        .toggle("Distances", true)
    ],
    gallery: [
        (name: "Empty", view: pushed { CardListView(cards: []) }),
        (name: "Single", view: pushed { CardListView(cards: Array(CardSummary.samples.prefix(1))) }),
        (name: "Full", view: pushed { CardListView(cards: CardSummary.samples) }),
        (name: "Long name", view: pushed { CardListView(cards: [.longName] + CardSummary.samples) })
    ]
) { knobs in
    pushed {
        CardListView(
            cards: CardSummary.samples.prefix(knobs.integer("Cards")).map { card in
                CardSummary(
                    id: card.id,
                    name: card.name,
                    color: knobs.bool("Colours") ? card.color : .standard,
                    proximity: knobs.bool("Distances") ? card.proximity : nil
                )
            }
        )
    }
}

@MainActor
private let cardDetailStory = Story(
    id: "card-detail",
    title: "CardDetailView",
    section: "Screens",
    galleryLayout: .oneAtATime,
    knobs: [
        .text("Name", CardDetail.sample.name),
        .text("Code", CardDetail.sample.code),
        .options("Type", BarcodeType.allNames, BarcodeType.ean13.rawValue),
        .options("Colour", CardColor.allNames, CardDetail.sample.color.rawValue),
        .number("Created (days ago)", 30, in: 0...3_650, step: 1),
        .toggle("Brightness boost", true)
    ] + ProximityKnobs.knobs(place: "Boots Westfield", distance: 320),
    gallery: [CardDetail.sample, .qr, .invalidCode].map { card in
        (
            name: card.name,
            view: pushed {
                Stateful(true) { boost in
                    CardDetailView(card: card, brightnessBoost: boost)
                }
            }
        )
    }
) { knobs in
    let card = CardDetail(
        id: "story",
        name: knobs.string("Name"),
        code: knobs.string("Code"),
        barcodeType: .named(knobs.option("Type")),
        timestamp: Date.now.addingTimeInterval(-knobs.number("Created (days ago)") * 86_400),
        color: .named(knobs.option("Colour")),
        proximity: knobs.proximity()
    )
    return pushed {
        CardDetailView(card: card, brightnessBoost: knobs.boolBinding("Brightness boost"))
    }
}

@MainActor
private let cardEditStory = Story(
    id: "card-edit",
    title: "CardEditView",
    section: "Screens",
    galleryLayout: .oneAtATime,
    knobs: [
        .text("Name", CardDraft.sample.name),
        .text("Code", CardDraft.sample.code),
        .options("Type", BarcodeType.allNames, BarcodeType.code128.rawValue),
        .options("Colour", CardColor.allNames, CardDraft.sample.color.rawValue),
        .number("Locations", 1, in: 0...Double(CardLocation.samples.count), step: 1),
        .toggle("Shows scanner", false),
        .toggle("Autofocus name", false)
    ],
    gallery: [
        (
            name: "Edit existing",
            view: pushed {
                EditCardStory(draft: .sample, title: "Edit Card", showsScanner: false)
            }
        ),
        (
            name: "Add new, with scanner",
            view: pushed {
                EditCardStory(draft: .empty, title: "Add Card", showsScanner: true)
            }
        )
    ]
) { knobs in
    let draft = Binding(
        get: {
            CardDraft(
                name: knobs.string("Name"),
                code: knobs.string("Code"),
                barcodeType: .named(knobs.option("Type")),
                color: .named(knobs.option("Colour")),
                locations: Array(CardLocation.samples.prefix(knobs.integer("Locations")))
            )
        },
        set: { (updated: CardDraft) in
            knobs.set(updated.name, for: "Name")
            knobs.set(updated.code, for: "Code")
            knobs.select(updated.barcodeType.rawValue, for: "Type")
            knobs.select(updated.color.rawValue, for: "Colour")
            knobs.set(Double(updated.locations.count), for: "Locations")
        }
    )
    return pushed {
        CardEditView(
            draft: draft,
            autofocusesName: knobs.bool("Autofocus name"),
            showsScanner: knobs.bool("Shows scanner")
        ) {
            ScannerPlaceholderView()
        }
        .navigationTitle("Card")
    }
}

@MainActor
private let locationPickerStory = Story(
    id: "location-picker",
    title: "LocationPickerView",
    section: "Screens",
    galleryLayout: .oneAtATime,
    knobs: [
        .options("Start at", PickerStart.allCases.map(\.rawValue), PickerStart.westway.rawValue),
        .toggle("Postcode found", true)
    ],
    gallery: [
        (
            name: "Westway",
            view: standalone {
                LocationPickerView(
                    initialPosition: .region(CardLocation.previewRegion),
                    findPlace: { _ in nil },
                    onAdd: { _ in }
                )
            }
        )
    ]
) { knobs in
    let start = PickerStart(rawValue: knobs.option("Start at")) ?? .westway
    let found = knobs.bool("Postcode found")
    return standalone {
        LocationPickerView(
            initialPosition: start.position,
            findPlace: { query in
                found ? PlaceMatch(name: query.uppercased(), latitude: 51.5203, longitude: -0.2094) : nil
            },
            onAdd: { _ in }
        )
        // The start position is read once, so a new choice needs a fresh picker.
        .id(start)
    }
}

private enum PickerStart: String, CaseIterable {
    case westway = "Westway"
    case centralLondon = "Central London"
    case userLocation = "Your location"

    var position: MapCameraPosition {
        switch self {
        case .westway:
            .region(CardLocation.previewRegion)
        case .centralLondon:
            .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                    latitudinalMeters: 3_000,
                    longitudinalMeters: 3_000
                )
            )
        case .userLocation:
            .userLocation(fallback: .automatic)
        }
    }
}

@MainActor
private let settingsStory = Story(
    id: "settings",
    title: "SettingsListView",
    section: "Screens",
    galleryLayout: .oneAtATime,
    knobs: [
        .text("Version", "1.1"),
        .text("Build", "42"),
        .text("Author", "Paul Serby"),
        .text("Author URL", "https://github.com/serby"),
        .number("Card count", 6, in: 0...50, step: 1),
        .toggle("Brightness boost", true),
        .text("Message", "")
    ],
    gallery: [
        (
            name: "With cards",
            view: pushed {
                Stateful(true) { boost in
                    SettingsListView(state: .sample, brightnessBoost: boost)
                }
            }
        ),
        (
            name: "No cards",
            view: pushed {
                Stateful(false) { boost in
                    SettingsListView(state: .noCards, brightnessBoost: boost)
                }
            }
        )
    ]
) { knobs in
    let state = SettingsState(
        appVersion: knobs.string("Version"),
        appBuild: knobs.string("Build"),
        authorName: knobs.string("Author"),
        authorURL: URL(string: knobs.string("Author URL")),
        cardCount: knobs.integer("Card count")
    )
    // An empty Message knob means no alert.
    let message = Binding<String?>(
        get: { knobs.string("Message").isEmpty ? nil : knobs.string("Message") },
        set: { knobs.set($0 ?? "", for: "Message") }
    )
    return pushed {
        SettingsListView(
            state: state,
            brightnessBoost: knobs.boolBinding("Brightness boost"),
            message: message
        )
    }
}

@MainActor
private let importCardsStory = Story(
    id: "import-cards",
    title: "ImportCardsView",
    section: "Screens",
    galleryLayout: .oneAtATime,
    knobs: [
        .text("Import text", ""),
        .text("Clipboard", sampleExportJSON)
    ],
    gallery: [
        (
            name: "Empty",
            view: standalone {
                Stateful("") { text in
                    ImportCardsView(importText: text, onImport: {})
                }
            }
        ),
        (
            name: "Pasted",
            view: standalone {
                Stateful(sampleExportJSON) { text in
                    ImportCardsView(importText: text, onImport: {})
                }
            }
        )
    ]
) { knobs in
    let clipboard = knobs.string("Clipboard")
    return standalone {
        ImportCardsView(
            importText: knobs.stringBinding("Import text"),
            readClipboard: { clipboard.isEmpty ? nil : clipboard },
            onImport: {}
        )
    }
}

private let sampleExportJSON = """
[{"code":"9780201379624","color":"indigo","name":"Boots Advantage","order":0,"timestamp":"2023-11-14T22:13:20Z","type":"EAN-13"}]
"""

#endif
