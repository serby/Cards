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
    /// Where the card screens zoom up from, or nil for no zoom (CARD-4).
    private let zoom: Namespace.ID?
    @State private var toolbarVisible = true
    @State private var searchPresented = false
    @State private var deleteTrigger = false
    @State private var dropTarget: CardSummary.ID?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityAnnouncer) private var announcer

    /// - Parameters:
    ///   - cards: The cards to show, already searched and in order.
    ///   - cardHere: The card for where you are, shown above the grid (SET-3).
    ///   - zoom: The namespace the tiles and the card for where you are are
    ///     sources in, for a card's screen to zoom up out of (CARD-4).
    public init(
        cards: [CardSummary],
        cardHere: CardDetail? = nil,
        search: Binding<String> = .constant(""),
        sortOrder: Binding<CardSortOrder> = .constant(.custom),
        zoom: Namespace.ID? = nil,
        actions: CardListActions = CardListActions()
    ) {
        self.cards = cards
        self.cardHere = cardHere
        _search = search
        _sortOrder = sortOrder
        self.zoom = zoom
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
        .navigationTitle(Text("Cards", comment: "Title of the screen that lists the user's loyalty cards."))
        .searchable(text: $search, isPresented: $searchPresented)
        .sensoryFeedback(trigger: deleteTrigger, { SensoryFeedback.impact(weight: .medium) })
        // Kept while searching, so the search field does not scroll away under you.
        .toolbar(toolbarVisible || searchPresented || isSearching ? .visible : .hidden, for: .navigationBar)
        .toolbar { toolbarItems }
        // Hidden once the cards are scrolled down, and only when they are
        // taller than the screen: a drag on a list that fits only bounces it,
        // and hid the bar and brought it back, moving everything under it.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            let insets = geometry.contentInsets.top + geometry.contentInsets.bottom
            return geometry.contentOffset.y > 0 && geometry.contentSize.height + insets > geometry.containerSize.height
        } action: { _, isScrolledDown in
            withAnimation(.easeInOut(duration: 0.3)) {
                toolbarVisible = !isScrolledDown
            }
        }
    }

    private var isSearching: Bool { CardArrangement.isFiltering(search) }

    /// No cards at all, rather than none matching a search: the empty state
    /// then offers its own Add Card button.
    private var hasNoCards: Bool { cards.isEmpty && !isSearching }

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
                    onEdit: { actions.editCard(card.id) },
                    onDelete: { delete(card) },
                    onMoveUp: move(card, by: -1),
                    onMoveDown: move(card, by: 1)
                )
                .zoomSource(CardZoomSource(.tile, cardID: card.id), in: zoom)
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

    /// The tile's Move Up or Move Down: `card` one place earlier or later in
    /// custom order, as dropping it on its neighbour would. Nil where the card
    /// cannot go that way, or the order cannot be rearranged.
    private func move(_ card: CardSummary, by offset: Int) -> (() -> Void)? {
        guard canReorder,
              let index = cards.firstIndex(of: card),
              cards.indices.contains(index + offset)
        else { return nil }
        let target = cards[index + offset].id
        return { actions.moveCard(card.id, target) }
    }

    /// Deletes with a haptic, and says which card went, as the tile just
    /// disappears.
    private func delete(_ card: CardSummary) {
        deleteTrigger.toggle()
        actions.deleteCard(card.id)
        announcer.announce(Announcements.deletedCards([card.name]))
    }

    private func cardWhereYouAre(_ card: CardDetail) -> some View {
        Button {
            if let select = actions.selectCardWhereYouAre {
                select(card.id)
            } else {
                actions.selectCard(card.id)
            }
        } label: {
            CardFaceView(card: card, style: .lockUp)
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
        .zoomSource(CardZoomSource(.cardWhereYouAre, cardID: card.id), in: zoom)
        // As wide as on the card's screen, which leaves room for the grid on an iPad (CARD-4).
        .cardColumn()
        .accessibilityHint(
            Text(
                "Opens the card for where you are",
                comment: "VoiceOver hint for the card shown in full at the top of the Cards tab when the user is at one of its places."
            )
        )
        .accessibilityIdentifier("cardWhereYouAre")
    }

    @ViewBuilder
    private var emptyState: some View {
        if cards.isEmpty {
            if isSearching {
                ContentUnavailableView {
                    Label(
                        LocalizedStringResource("No Cards Match", comment: "Title shown on the Cards tab when no card's name matches the search."),
                        systemImage: "magnifyingglass"
                    )
                    .accessibilityIdentifier("noCardsMatchTitle")
                } description: {
                    Text(
                        "Check the spelling, or try another name.",
                        comment: "Under “No Cards Match” on the Cards tab, when a search finds no card."
                    )
                }
            } else {
                ContentUnavailableView {
                    Label(
                        LocalizedStringResource("No Cards Yet", comment: "Title of the empty card list, before the user has added a card."),
                        systemImage: "barcode.viewfinder"
                    )
                } description: {
                    Text("Scan the barcode on a loyalty card to add it.", comment: "Under “No Cards Yet” on the empty card list.")
                } actions: {
                    Button(action: actions.addCard) {
                        Text("Add Card", comment: "Button on the empty card list that opens the form for a new card.")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("addFirstCardButton")
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker(selection: $sortOrder) {
                    ForEach(CardSortOrder.allCases) { order in
                        Label(order.title, systemImage: order.systemImage)
                            .tag(order)
                            .accessibilityIdentifier("sortOrder_\(order.rawValue)")
                    }
                } label: {
                    Text("Sort By", comment: "Heading of the choices in the Cards tab's Sort menu, which sets the order of the cards.")
                }
            } label: {
                Label(
                    LocalizedStringResource(
                        "Sort",
                        comment: "VoiceOver label for the toolbar menu on the Cards tab that chooses the order of the cards. A verb."
                    ),
                    systemImage: "arrow.up.arrow.down"
                )
            }
            .foregroundColor(.accent)
            .accessibilityIdentifier("sortMenu")
        }
        // While there are no cards the empty list's own Add Card button is the
        // one to use; two buttons with one name would make Voice Control ask which.
        if !hasNoCards {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: actions.addCard) {
                    Image(systemName: "barcode.viewfinder")
                }
                .foregroundColor(.accent)
                .keyboardShortcut("n")
                .accessibilityIdentifier("addCardButton")
                .accessibilityLabel(
                    Text("Add Card", comment: "VoiceOver label for the toolbar button, a barcode scanner icon, that adds a new card.")
                )
            }
        }
    }
}

extension CardSortOrder {
    var title: LocalizedStringResource {
        switch self {
        case .lastViewed:
            LocalizedStringResource(
                "Last Viewed",
                comment: "Choice in the Cards tab's Sort menu: the card opened most recently first."
            )
        case .custom:
            LocalizedStringResource(
                "Custom Order",
                comment: "Choice in the Cards tab's Sort menu: the order the user set by dragging the cards."
            )
        case .location:
            LocalizedStringResource(
                "Location",
                comment: "Choice in the Cards tab's Sort menu: the cards with places nearest to the user first. A noun."
            )
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

private extension View {
    /// A source for a card's screen to zoom up out of, when there is a namespace.
    @ViewBuilder
    func zoomSource(_ source: CardZoomSource, in zoom: Namespace.ID?) -> some View {
        if let zoom {
            // The zoom keeps the card's rounded corners all the way.
            matchedTransitionSource(id: source, in: zoom) { $0.clipShape(CardTileView.shape) }
        } else {
            self
        }
    }
}

#if DEBUG
#Preview("Populated") {
    NavigationStack {
        CardListView(cards: CardSummary.samples)
    }
}

#Preview("Empty") {
    NavigationStack {
        CardListView(cards: [])
    }
}
#endif
