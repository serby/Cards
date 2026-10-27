#if DEBUG
import SwiftUI

/// Screens carry their own navigation chrome, so gallery entries get a fixed
/// height rather than fighting the enclosing scroll view.
private let galleryScreenHeight: CGFloat = 480

@MainActor
let screenStories: [Story] = [
    cardListStory,
    cardDetailStory,
    cardEditStory,
    settingsStory
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

@MainActor
private func screen<Content: View>(@ViewBuilder _ content: () -> Content) -> AnyView {
    AnyView(
        NavigationStack(root: content)
            .frame(height: galleryScreenHeight)
    )
}

@MainActor
private let cardListStory = Story(
    id: "card-list",
    title: "CardListView",
    section: "Screens",
    knobs: [
        .number("Cards", 6, in: 0...Double(CardSummary.samples.count), step: 1)
    ],
    gallery: [
        (name: "Empty", view: screen { CardListView(cards: []) }),
        (name: "Single", view: screen { CardListView(cards: Array(CardSummary.samples.prefix(1))) }),
        (name: "Full", view: screen { CardListView(cards: CardSummary.samples) }),
        (name: "Long name", view: screen { CardListView(cards: [.longName] + CardSummary.samples) })
    ]
) { knobs in
    AnyView(
        NavigationStack {
            CardListView(cards: Array(CardSummary.samples.prefix(knobs.integer("Cards"))))
        }
    )
}

@MainActor
private let cardDetailStory = Story(
    id: "card-detail",
    title: "CardDetailView",
    section: "Screens",
    knobs: [
        .text("Name", CardDetail.sample.name),
        .text("Code", CardDetail.sample.code),
        .options("Type", BarcodeType.allNames, BarcodeType.ean13.rawValue),
        .toggle("Brightness boost", true)
    ],
    gallery: [CardDetail.sample, .qr, .invalidCode].map { card in
        (
            name: card.name,
            view: screen {
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
        timestamp: CardDetail.sample.timestamp
    )
    return AnyView(
        NavigationStack {
            CardDetailView(card: card, brightnessBoost: knobs.boolBinding("Brightness boost"))
        }
    )
}

@MainActor
private let cardEditStory = Story(
    id: "card-edit",
    title: "CardEditView",
    section: "Screens",
    knobs: [
        .text("Name", CardDraft.sample.name),
        .text("Code", CardDraft.sample.code),
        .options("Type", BarcodeType.allNames, BarcodeType.code128.rawValue),
        .toggle("Shows scanner", false),
        .toggle("Autofocus name", false)
    ],
    gallery: [
        (
            name: "Edit existing",
            view: screen {
                EditCardStory(draft: .sample, title: "Edit Card", showsScanner: false)
            }
        ),
        (
            name: "Add new, with scanner",
            view: screen {
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
                barcodeType: .named(knobs.option("Type"))
            )
        },
        set: { (updated: CardDraft) in
            knobs.set(updated.name, for: "Name")
            knobs.set(updated.code, for: "Code")
            knobs.select(updated.barcodeType.rawValue, for: "Type")
        }
    )
    return AnyView(
        NavigationStack {
            CardEditView(
                draft: draft,
                autofocusesName: knobs.bool("Autofocus name"),
                showsScanner: knobs.bool("Shows scanner")
            ) {
                ScannerPlaceholderView()
            }
            .navigationTitle("Card")
        }
    )
}

@MainActor
private let settingsStory = Story(
    id: "settings",
    title: "SettingsListView",
    section: "Screens",
    knobs: [
        .text("Version", "1.1"),
        .text("Build", "42"),
        .number("Card count", 6, in: 0...50, step: 1),
        .toggle("Brightness boost", true)
    ],
    gallery: [
        (
            name: "With cards",
            view: screen {
                Stateful(true) { boost in
                    SettingsListView(state: .sample, brightnessBoost: boost)
                }
            }
        ),
        (
            name: "No cards",
            view: screen {
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
        authorName: "Paul Serby",
        authorURL: URL(string: "https://github.com/serby"),
        cardCount: knobs.integer("Card count")
    )
    return AnyView(
        NavigationStack {
            SettingsListView(
                state: state,
                brightnessBoost: knobs.boolBinding("Brightness boost")
            )
        }
    )
}

#endif
