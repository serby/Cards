import AppIntents
import WidgetKit

/// The widget's settings: which card to show. "Nearest card" is the default.
struct SelectCardIntent: WidgetConfigurationIntent {
    static let title = LocalizedStringResource(
        "Choose Card",
        comment: "Title of the Home Screen widget's settings, where the user picks which card it shows. A verb phrase."
    )
    static let description = IntentDescription(
        LocalizedStringResource(
            "Pick a card, or let the widget show the one nearest to you.",
            comment: "Description under the title of the Home Screen widget's settings."
        )
    )

    @Parameter(
        title: LocalizedStringResource(
            "Card",
            comment: """
                A noun: one loyalty card. The Home Screen widget's name in the widget gallery, the title of its setting for which card to \
                show, and what Shortcuts calls a card.
                """
        )
    )
    var card: CardEntity?
}

/// A card as offered in the widget's settings, plus the "Nearest card" choice.
struct CardEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource(
            "Card",
            comment: """
                A noun: one loyalty card. The Home Screen widget's name in the widget gallery, the title of its setting for which card to \
                show, and what Shortcuts calls a card.
                """
        )
    )
    static let defaultQuery = CardEntityQuery()
    static let nearest = Self(id: "nearest", name: "", code: nil)

    let id: String
    /// The card's name, as the user typed it; empty for "Nearest card".
    let name: String
    /// nil for "Nearest card".
    let code: String?

    init(id: String, name: String, code: String?) {
        self.id = id
        self.name = name
        self.code = code
    }

    init(_ card: WidgetCard) {
        self.init(id: "card:\(card.code)", name: card.name, code: card.code)
    }

    /// Resolved where it is shown, in the language of the widget's settings.
    /// A card's name is the user's own and is never looked up: it fills the
    /// catalogue's "%@", which is marked not to be translated.
    var displayRepresentation: DisplayRepresentation {
        if code == nil {
            DisplayRepresentation(
                title: LocalizedStringResource(
                    "Nearest card",
                    comment: "In the Home Screen widget's settings: the choice that shows whichever card has the place nearest to you. The default."
                )
            )
        } else {
            DisplayRepresentation(
                title: LocalizedStringResource(
                    "\(name)",
                    comment: "A card's name in the Home Screen widget's settings, exactly as the user typed it. Never translated."
                )
            )
        }
    }
}

struct CardEntityQuery: EntityQuery {
    func entities(for identifiers: [CardEntity.ID]) async throws -> [CardEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CardEntity] {
        [.nearest] + WidgetSnapshot.read().map(CardEntity.init)
    }

    func defaultResult() async -> CardEntity? {
        .nearest
    }
}

/// Run by the widget's refresh button. WidgetKit reloads the widget once the
/// intent finishes, which finds the nearest card from a fresh location.
struct RefreshCardWidgetIntent: AppIntent {
    static let title = LocalizedStringResource(
        "Find Nearest Card",
        comment: "Title of the action behind the Home Screen widget's refresh button, which finds the card nearest to you again."
    )
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        .result()
    }
}
