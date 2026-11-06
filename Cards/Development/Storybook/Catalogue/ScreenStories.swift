import MapKit
import SwiftUI

@MainActor
let screenStories: [Story] = [
    cardListStory,
    cardDetailStory,
    cardEditStory,
    locationPickerStory,
    sharedCardStory,
    settingsStory,
    changelogStory,
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
        .toggle("Distances", true),
        .toggle("Symbols", true),
        .toggle("Card where you are", false),
        .text("Search", ""),
        .options("Sort", CardSortOrder.allCases.map(\.rawValue), CardSortOrder.custom.rawValue)
    ],
    gallery: [
        (name: "Empty", view: pushed { CardListView(cards: []) }),
        (name: "Single", view: pushed { CardListView(cards: Array(CardSummary.samples.prefix(1))) }),
        (name: "Full", view: pushed { CardListView(cards: CardSummary.samples) }),
        (name: "Long name", view: pushed { CardListView(cards: [.longName] + CardSummary.samples) }),
        (name: "Card where you are", view: pushed { CardListView(cards: CardSummary.samples, cardHere: .here) }),
        (name: "Search, no match", view: pushed { CardListView(cards: [], search: .constant("Waitrose")) })
    ]
) { knobs in
    let search = knobs.string("Search")
    let sortOrder = Binding(get: { CardSortOrder(rawValue: knobs.option("Sort")) ?? .custom }, set: { knobs.select($0.rawValue, for: "Sort") })
    return pushed {
        CardListView(
            cards: CardSummary.samples.prefix(knobs.integer("Cards"))
                .filter { CardArrangement.name($0.name, matches: search) }
                .map { card in
                    CardSummary(
                        id: card.id,
                        name: card.name,
                        color: knobs.bool("Colours") ? card.color : .standard,
                        proximity: knobs.bool("Distances") ? card.proximity : nil,
                        symbol: knobs.bool("Symbols") ? card.symbol : nil
                    )
                },
            cardHere: knobs.bool("Card where you are") ? .here : nil,
            search: knobs.stringBinding("Search"),
            sortOrder: sortOrder
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
        SymbolKnob.knob(CardDetail.sample.symbol),
        .number("Created (days ago)", 30, in: 0...3_650, step: 1),
        .toggle("Brightness boost", true),
        .toggle("Map opens at Westway", true),
        .toggle("Share menu", true)
    ] + ProximityKnobs.knobs(place: "Boots Westfield", distance: 320),
    gallery: [CardDetail.sample, .qr, .invalidCode].map { card in
        (
            name: card.name,
            view: pushed {
                Stateful(true) { boost in
                    CardDetailView(card: card, brightnessBoost: boost, share: .sample(for: card))
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
        proximity: knobs.proximity(),
        symbol: knobs.symbol
    )
    return pushed {
        CardDetailView(
            card: card,
            brightnessBoost: knobs.boolBinding("Brightness boost"),
            mapCentre: knobs.bool("Map opens at Westway") ? CardLocation.sample.coordinate : nil,
            share: knobs.bool("Share menu") ? .sample(for: card) : nil
        )
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
        SymbolKnob.knob(CardDraft.sample.symbol),
        .number("Locations", 1, in: 0...Double(CardLocation.samples.count), step: 1),
        .toggle("Notify on arrival", true),
        .toggle("Arrival notifications on", true),
        .toggle("Code already used", false),
        .toggle("Shows scanner", false),
        .toggle("Autofocus name", false),
        .toggle("Map opens at Westway", true)
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
                locations: Array(CardLocation.samples.prefix(knobs.integer("Locations"))),
                notifiesOnArrival: knobs.bool("Notify on arrival"),
                symbol: knobs.symbol
            )
        },
        set: { (updated: CardDraft) in
            knobs.set(updated.name, for: "Name")
            knobs.set(updated.code, for: "Code")
            knobs.select(updated.barcodeType.rawValue, for: "Type")
            knobs.select(updated.color.rawValue, for: "Colour")
            knobs.symbolBinding.wrappedValue = updated.symbol
            knobs.set(Double(updated.locations.count), for: "Locations")
            knobs.set(updated.notifiesOnArrival, for: "Notify on arrival")
        }
    )
    return pushed {
        CardEditView(
            draft: draft,
            autofocusesName: knobs.bool("Autofocus name"),
            mapCentre: knobs.bool("Map opens at Westway") ? CardLocation.sample.coordinate : nil,
            takenCodes: knobs.bool("Code already used") ? [knobs.string("Code")] : [],
            arrivalNotificationsEnabled: knobs.bool("Arrival notifications on"),
            showsScanner: knobs.bool("Shows scanner")
        ) {
            ScannerPlaceholderView()
        }
        .navigationTitle("Card")
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
        .toggle("Arrival notifications", true),
        .toggle("Show card where I am", false),
        .toggle("Notifications blocked", false),
        .toggle("Has What's New", true),
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
        ),
        (
            name: "Notifications blocked",
            view: pushed {
                Stateful(true) { arrivals in
                    SettingsListView(state: .withNotificationsBlocked, brightnessBoost: .constant(true), arrivalNotifications: arrivals)
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
        cardCount: knobs.integer("Card count"),
        notificationsBlocked: knobs.bool("Notifications blocked"),
        changelog: knobs.bool("Has What's New") ? ChangelogVersion.samples : []
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
            arrivalNotifications: knobs.boolBinding("Arrival notifications"),
            showsCardWhereYouAre: knobs.boolBinding("Show card where I am"),
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

@MainActor
private let changelogStory = Story(
    id: "changelog",
    title: "ChangelogView",
    section: "Screens",
    galleryLayout: .oneAtATime,
    knobs: [
        .number("Versions", 2, in: 0...Double(ChangelogVersion.samples.count), step: 1),
        .toggle("Newest in preparation", true)
    ],
    gallery: [
        (name: "Two versions", view: pushed { ChangelogView(versions: ChangelogVersion.samples) }),
        (name: "Empty", view: pushed { ChangelogView(versions: []) })
    ]
) { knobs in
    var versions = Array(ChangelogVersion.samples.prefix(knobs.integer("Versions")))
    if let newest = versions.first, !knobs.bool("Newest in preparation") {
        versions[0] = ChangelogVersion(version: newest.version, date: Date(timeIntervalSince1970: 1_780_000_000), changes: newest.changes)
    }
    return pushed { ChangelogView(versions: versions) }
}
