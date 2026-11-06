import SwiftData
import SwiftUI

/// Connects the "Add Card?" sheet to the store (SHARE-3): reads the card in the
/// link, checks it against the cards already here by the import rules, and
/// adds it at the end of the list or opens the one already here.
public struct SharedCardScreen: View {
    private let card: SharedCard?
    private let navigationManager: NavigationManager
    @Query private var cards: [CardItem]
    @Environment(\.modelContext) private var modelContext
    /// When the sheet opened: the date the face shows, which adding then records.
    @State private var openedAt = Date.now
    /// The card's places as the sheet lists them, made once so their ids stay put.
    @State private var places: [CardLocation]

    public init(link: SharedCardLink, navigationManager: NavigationManager) {
        card = link.card
        _places = State(initialValue: card?.locations ?? [])
        self.navigationManager = navigationManager
    }

    public var body: some View {
        SharedCardView(state: state, actions: SharedCardActions(add: add, open: open))
    }

    private var state: SharedCardState {
        guard let card else { return .unreadable }
        let face = CardDetail(
            id: card.code,
            name: card.name,
            code: card.code,
            barcodeType: card.barcodeType,
            timestamp: openedAt,
            color: card.color,
            symbol: card.symbol
        )
        return existingCode == nil ? .new(face, places: places) : .alreadyAdded(face, places: places)
    }

    /// The code of the card already here with the shared card's code, as it is
    /// stored, or nil if there is none. The import rules decide what counts.
    private var existingCode: String? {
        guard let card, card.importResult(existing: cards, addedAt: openedAt).alreadyHere > 0 else { return nil }
        return cards.first { $0.code.trimmingCharacters(in: .whitespacesAndNewlines) == card.code }?.code ?? card.code
    }

    private func add() {
        guard let card else { return }
        guard let added = card.importResult(existing: cards, addedAt: openedAt).added.first else {
            // Added meanwhile, on this device or through iCloud, so show it instead.
            open()
            return
        }
        modelContext.insert(added)
        try? modelContext.save()
        // Navigating closes the sheet.
        navigationManager.navigate(to: .card(added.code))
    }

    private func open() {
        guard let code = existingCode else { return }
        navigationManager.navigate(to: .card(code))
    }
}

#if DEBUG
#Preview {
    SharedCardScreen(
        link: SharedCardLink(card: SharedCard(name: "Library", code: "29876543210", color: .teal, symbol: "books.vertical.fill")),
        navigationManager: NavigationManager()
    )
    .modelContainer(for: CardItem.self, inMemory: true)
}
#endif
