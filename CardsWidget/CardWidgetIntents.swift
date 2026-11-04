import AppIntents
import WidgetKit

/// The widget's settings: which card to show. "Nearest card" is the default.
struct SelectCardIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Card"
    static let description = IntentDescription("Pick a card, or let the widget show the one nearest to you.")

    @Parameter(title: "Card")
    var card: CardEntity?
}

/// A card as offered in the widget's settings, plus the "Nearest card" choice.
struct CardEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Card"
    static let defaultQuery = CardEntityQuery()
    static let nearest = Self(id: "nearest", name: "Nearest card", code: nil)

    let id: String
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

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
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
    static let title: LocalizedStringResource = "Find Nearest Card"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        .result()
    }
}
