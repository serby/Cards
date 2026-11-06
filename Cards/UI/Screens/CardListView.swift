import SwiftUI

/// The Cards tab: the card for where you are, then every card as a tile in a
/// grid, with search and a choice of order. Driven entirely by its inputs and
/// `actions`.
public struct CardListView: View {
    private let cards: [CardSummary]
    private let cardHere: CardDetail?
    @Binding private var search: String
    @Binding private var sortOrder: CardSortOrder
    private let actions: CardListActions
    @State private var toolbarVisible = true
    @State private var searchPresented = false
    @State private var deleteTrigger = false
    @State private var dropTarget: CardSummary.ID?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// - Parameters:
    ///   - cards: The cards to show, already searched and in order.
    ///   - cardHere: The card for where you are, shown in full above the grid (SET-3).
    public init(
        cards: [CardSummary],
        cardHere: CardDetail? = nil,
        search: Binding<String> = .constant(""),
        sortOrder: Binding<CardSortOrder> = .constant(.custom),
        actions: CardListActions = CardListActions()
    ) {
        self.cards = cards
        self.cardHere = cardHere
        _search = search
        _sortOrder = sortOrder
        self.actions = actions
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let cardHere {
                    cardWhereYouAre(cardHere)
                }
                grid
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .overlay { emptyState }
        .background(Color.primaryBackground)
        .navigationTitle("Cards")
        .searchable(text: $search, isPresented: $searchPresented)
        .sensoryFeedback(trigger: deleteTrigger, { SensoryFeedback.impact(weight: .medium) })
        // Kept while searching, so the search field does not scroll away under you.
        .toolbar(toolbarVisible || searchPresented || isSearching ? .visible : .hidden, for: .navigationBar)
        .toolbar { toolbarItems }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                toolbarVisible = newValue <= 0
            }
        }
    }

    private var isSearching: Bool { CardArrangement.isFiltering(search) }

    /// Only custom order can be rearranged, and only with every card showing.
    private var canReorder: Bool { sortOrder == .custom && !isSearching }

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
                CardTileView(
                    card: card,
                    isDropTarget: dropTarget == card.id,
                    onTap: { actions.selectCard(card.id) },
                    onDelete: {
                        deleteTrigger.toggle()
                        actions.deleteCard(card.id)
                    }
                )
                .if(canReorder) { tile in
                    reorderable(tile, card: card)
                }
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

    private func cardWhereYouAre(_ card: CardDetail) -> some View {
        Button {
            actions.selectCard(card.id)
        } label: {
            CardFaceView(card: card)
                // Read as the tile is, the name and then the distance, rather than every part of the face.
                .accessibilityRepresentation {
                    HStack {
                        Text(card.name)
                        if let proximity = card.proximity {
                            ProximityLabel(proximity)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
        }
        .buttonStyle(.plain)
        // A card face as wide as an iPad would leave no room for the grid.
        .frame(maxWidth: 560)
        .accessibilityHint("Opens the card for where you are")
        .accessibilityIdentifier("cardWhereYouAre")
    }

    @ViewBuilder
    private var emptyState: some View {
        if cards.isEmpty {
            if isSearching {
                ContentUnavailableView {
                    Label("No Cards Match", systemImage: "magnifyingglass")
                } description: {
                    Text("Check the spelling, or try another name.")
                }
            } else {
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
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort By", selection: $sortOrder) {
                    ForEach(CardSortOrder.allCases) { order in
                        Label(order.title, systemImage: order.systemImage)
                            .tag(order)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .foregroundColor(.accent)
            .accessibilityIdentifier("sortMenu")
        }
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

extension CardSortOrder {
    var title: String {
        switch self {
        case .lastViewed:
            "Last Viewed"
        case .custom:
            "Custom Order"
        case .location:
            "Location"
        }
    }

    var systemImage: String {
        switch self {
        case .lastViewed:
            "clock"
        case .custom:
            "line.3.horizontal"
        case .location:
            "location"
        }
    }
}
