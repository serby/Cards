import Foundation

/// Callbacks a card list raises. Defaults are no-ops so stories and previews
/// can supply only the ones they care about.
@MainActor
public struct CardListActions {
    public var selectCard: (CardSummary.ID) -> Void
    public var addCard: () -> Void
    public var deleteCards: (IndexSet) -> Void
    public var moveCards: (IndexSet, Int) -> Void

    public init(
        selectCard: @escaping (CardSummary.ID) -> Void = { _ in },
        addCard: @escaping () -> Void = {},
        deleteCards: @escaping (IndexSet) -> Void = { _ in },
        moveCards: @escaping (IndexSet, Int) -> Void = { _, _ in }
    ) {
        self.selectCard = selectCard
        self.addCard = addCard
        self.deleteCards = deleteCards
        self.moveCards = moveCards
    }
}

@MainActor
public struct CardDetailActions {
    public var editCard: () -> Void

    public init(editCard: @escaping () -> Void = {}) {
        self.editCard = editCard
    }
}

@MainActor
public struct CardEditActions {
    public var save: () -> Void
    /// Called when the location picker opens, so the map can show where you are.
    public var requestLocationAccess: () -> Void
    public var findPlace: (String) async -> PlaceMatch?

    public init(
        save: @escaping () -> Void = {},
        requestLocationAccess: @escaping () -> Void = {},
        findPlace: @escaping (String) async -> PlaceMatch? = { _ in nil }
    ) {
        self.save = save
        self.requestLocationAccess = requestLocationAccess
        self.findPlace = findPlace
    }
}

@MainActor
public struct SettingsActions {
    public var exportCards: () -> Void
    public var importCards: (String) -> Void
    public var deleteAllCards: () -> Void
    public var readClipboard: () -> String?

    public init(
        exportCards: @escaping () -> Void = {},
        importCards: @escaping (String) -> Void = { _ in },
        deleteAllCards: @escaping () -> Void = {},
        readClipboard: @escaping () -> String? = { nil }
    ) {
        self.exportCards = exportCards
        self.importCards = importCards
        self.deleteAllCards = deleteAllCards
        self.readClipboard = readClipboard
    }
}
