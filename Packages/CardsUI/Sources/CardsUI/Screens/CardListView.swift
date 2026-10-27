import SwiftUI

public struct CardRowView: View {
    private let card: CardSummary
    private let onTap: () -> Void
    @State private var trigger = false

    public init(card: CardSummary, onTap: @escaping () -> Void) {
        self.card = card
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            trigger.toggle()
            onTap()
        } label: {
            Text(card.name)
                .padding(.vertical)
                .foregroundColor(.primaryText)
        }
        .sensoryFeedback(trigger: trigger, { SensoryFeedback.impact(weight: .heavy) })
    }
}

/// The card list, driven entirely by `cards` and `actions`.
public struct CardListView: View {
    private let cards: [CardSummary]
    private let actions: CardListActions
    @State private var toolbarVisible = true
    @State private var deleteTrigger = false

    public init(cards: [CardSummary], actions: CardListActions = CardListActions()) {
        self.cards = cards
        self.actions = actions
    }

    public var body: some View {
        List {
            ForEach(cards) { card in
                CardRowView(card: card) { actions.selectCard(card.id) }
                    .listRowBackground(Color.clear)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .onDelete { offsets in
                deleteTrigger.toggle()
                actions.deleteCards(offsets)
            }
            .onMove(perform: actions.moveCards)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.primaryBackground)
        .navigationTitle("Cards")
        .sensoryFeedback(trigger: deleteTrigger, { SensoryFeedback.impact(weight: .medium) })
        .toolbar(toolbarVisible ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: actions.addCard) {
                    Image(systemName: "barcode.viewfinder")
                }
                .foregroundColor(.accent)
                .accessibilityIdentifier("addCardButton")
                .accessibilityLabel("Add Card")
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                toolbarVisible = newValue <= 0
            }
        }
    }
}

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
