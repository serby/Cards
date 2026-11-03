import SwiftUI

public struct CardRowView: View {
    private let card: CardSummary
    private let onTap: () -> Void
    @State private var trigger = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(card: CardSummary, onTap: @escaping () -> Void) {
        self.card = card
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            trigger.toggle()
            onTap()
        } label: {
            layout {
                Text(card.name)
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let proximity = card.proximity {
                    ProximityLabel(proximity)
                        .font(.subheadline)
                        .foregroundStyle(proximity.isHere ? Color.primaryText : Color.secondaryText)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(card.color.rowFill, in: .rect(cornerRadius: 18))
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(trigger: trigger, { SensoryFeedback.impact(weight: .heavy) })
    }

    /// Name and distance side by side, stacked at accessibility text sizes.
    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
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
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            }
            .onDelete { offsets in
                deleteTrigger.toggle()
                actions.deleteCards(offsets)
            }
            .onMove(perform: actions.moveCards)
        }
        .listStyle(.plain)
        .overlay {
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
