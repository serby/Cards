import SwiftUI

/// The Cards tab: every card as a tile in a grid. Driven entirely by its
/// inputs and `actions`.
public struct CardListView: View {
    private let cards: [CardSummary]
    private let actions: CardListActions
    @State private var toolbarVisible = true
    @State private var deleteTrigger = false
    @State private var dropTarget: CardSummary.ID?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// - Parameter cards: The cards to show, in order.
    public init(cards: [CardSummary], actions: CardListActions = CardListActions()) {
        self.cards = cards
        self.actions = actions
    }

    public var body: some View {
        ScrollView {
            grid
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .overlay { emptyState }
        .background(Color.primaryBackground)
        .navigationTitle("Cards")
        .sensoryFeedback(trigger: deleteTrigger, { SensoryFeedback.impact(weight: .medium) })
        .toolbar(toolbarVisible ? .visible : .hidden, for: .navigationBar)
        .toolbar { toolbarItems }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                toolbarVisible = newValue <= 0
            }
        }
    }

    /// Two columns on iPhone and four on iPad, halved at the accessibility text
    /// sizes so names stay readable (A11Y-3).
    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 4 : 2
        return Array(
            repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
            count: dynamicTypeSize.isAccessibilitySize ? count / 2 : count
        )
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(cards) { card in
                reorderable(
                    CardTileView(
                        card: card,
                        isDropTarget: dropTarget == card.id,
                        onTap: { actions.selectCard(card.id) },
                        onDelete: {
                            deleteTrigger.toggle()
                            actions.deleteCard(card.id)
                        }
                    ),
                    card: card
                )
            }
        }
        .animation(.default, value: cards.map(\.id))
    }

    /// Drag a tile onto another and it takes that one's place (CARD-10).
    private func reorderable(_ tile: some View, card: CardSummary) -> some View {
        tile
            .contentShape(.dragPreview, CardTileView.shape)
            .draggable(card.id)
            .dropDestination(for: String.self) { codes, _ in
                guard let code = codes.first, code != card.id else { return false }
                actions.moveCard(code, card.id)
                return true
            } isTargeted: { isTargeted in
                if isTargeted {
                    dropTarget = card.id
                } else if dropTarget == card.id {
                    dropTarget = nil
                }
            }
    }

    @ViewBuilder
    private var emptyState: some View {
        if cards.isEmpty {
            ContentUnavailableView {
                Label("No Cards Yet", systemImage: "barcode.viewfinder")
            } description: {
                Text("Scan the barcode on a loyalty card to add it.")
            } actions: {
                Button("Add Card", action: actions.addCard)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: actions.addCard) {
                Image(systemName: "barcode.viewfinder")
            }
            .foregroundColor(.accent)
            .accessibilityIdentifier("addCardButton")
            .accessibilityLabel("Add Card")
        }
    }
}
