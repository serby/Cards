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
                    .foregroundStyle(card.color.rowInk)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let proximity = card.proximity {
                    ProximityLabel(proximity)
                        .font(.subheadline)
                        .foregroundStyle(card.color.rowInk)
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
    @State private var deleteTrigger = false

    public init(cards: [CardSummary], actions: CardListActions = CardListActions()) {
        self.cards = cards
        self.actions = actions
    }

    public var body: some View {
        List {
            ForEach(cards) { card in
                CardRowView(card: card) { actions.selectCard(card.id) }
                    .accessibilityIdentifier("cardRow_\(card.id)")
                    // Swiping and dragging are not the only ways: the menu serves
                    // pointer, keyboard, Voice Control and Switch Control, and the
                    // actions VoiceOver, whose swipe-to-delete is already an action.
                    .contextMenu {
                        moveButtons(for: card)
                        Divider()
                        Button(role: .destructive) {
                            delete(card)
                        } label: {
                            Label(
                                LocalizedStringResource(
                                    "Delete",
                                    comment: "Menu item that deletes a card in the list, or a place in the card form. A verb."
                                ),
                                systemImage: "trash"
                            )
                        }
                        .accessibilityIdentifier("deleteCardMenuItem")
                    }
                    .accessibilityActions { moveButtons(for: card) }
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
        .scrollContentBackground(.hidden)
        .background(Color.primaryBackground)
        .navigationTitle(Text("Cards", comment: "Title of the screen that lists the user's loyalty cards."))
        .sensoryFeedback(trigger: deleteTrigger, { SensoryFeedback.impact(weight: .medium) })
        .toolbar {
            // While the list is empty its own Add Card button is the one to use;
            // two buttons with one name would make Voice Control ask which.
            if !cards.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: actions.addCard) {
                        Image(systemName: "barcode.viewfinder")
                    }
                    .foregroundColor(.accent)
                    .accessibilityIdentifier("addCardButton")
                    .accessibilityLabel(
                        Text("Add Card", comment: "VoiceOver label for the toolbar button, a barcode scanner icon, that adds a new card.")
                    )
                }
            }
        }
    }

    /// Move Up and Move Down, where the card can move that way.
    @ViewBuilder
    private func moveButtons(for card: CardSummary) -> some View {
        if let index = cards.firstIndex(of: card) {
            if index > 0 {
                Button {
                    actions.moveCards(IndexSet(integer: index), index - 1)
                } label: {
                    Label(
                        LocalizedStringResource("Move Up", comment: "Menu item and VoiceOver action that moves a card one place up the list."),
                        systemImage: "arrow.up"
                    )
                }
                .accessibilityIdentifier("moveCardUpMenuItem")
            }
            if index < cards.count - 1 {
                Button {
                    // Past the next card, as a List move counts its destination.
                    actions.moveCards(IndexSet(integer: index), index + 2)
                } label: {
                    Label(
                        LocalizedStringResource("Move Down", comment: "Menu item and VoiceOver action that moves a card one place down the list."),
                        systemImage: "arrow.down"
                    )
                }
                .accessibilityIdentifier("moveCardDownMenuItem")
            }
        }
    }

    private func delete(_ card: CardSummary) {
        guard let index = cards.firstIndex(of: card) else { return }
        deleteTrigger.toggle()
        actions.deleteCards(IndexSet(integer: index))
    }
}
