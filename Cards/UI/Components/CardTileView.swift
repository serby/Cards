import SwiftUI

/// A card in the grid on the Cards tab: its full colour, its icon, its name
/// and how far away its nearest place is. VoiceOver reads it as one button,
/// the name and then the distance. A long press shows a menu with Move Up and
/// Move Down, where the card can move that way, and Delete; VoiceOver offers
/// the same as actions.
public struct CardTileView: View {
    /// The tile's outline, for its fill and for the previews iOS lifts from it
    /// for the menu and for dragging.
    public static let shape = RoundedRectangle(cornerRadius: CardGeometry.cornerRadius)

    private let card: CardSummary
    /// Whether a card being dragged is over this one, and would take its place.
    private let isDropTarget: Bool
    private let onTap: () -> Void
    private let onDelete: () -> Void
    /// Moves the card one place earlier, or later; nil where it cannot go that way.
    private let onMoveUp: (() -> Void)?
    private let onMoveDown: (() -> Void)?
    /// At least this tall, so a tile with a short name still looks like a card.
    /// It grows with the text, but only so far: at the largest sizes the text
    /// alone makes the tile tall enough.
    @ScaledMetric(relativeTo: .headline) private var minimumHeight: CGFloat = 112
    private static let tallestMinimumHeight: CGFloat = 200
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public init(
        card: CardSummary,
        isDropTarget: Bool = false,
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void = {},
        onMoveUp: (() -> Void)? = nil,
        onMoveDown: (() -> Void)? = nil
    ) {
        self.card = card
        self.isDropTarget = isDropTarget
        self.onTap = onTap
        self.onDelete = onDelete
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let icon = card.icon {
                        // The name already says what the card is (CARD-12).
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(card.color.ink)
                            .accessibilityHidden(true)
                    }
                    Spacer()
                    if let proximity = card.proximity {
                        // On a white panel, as text on a card colour is, its corners
                        // nested inside the tile's (docs/STYLE.md).
                        ProximityLabel(proximity, highlightsHere: false)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(CardPanel.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(CardPanel.fill, in: .rect(cornerRadius: CardGeometry.panelCornerRadius))
                    }
                }
                Spacer(minLength: 0)
                Text(card.name)
                    .font(.headline)
                    .foregroundStyle(card.color.ink)
                    .multilineTextAlignment(.leading)
            }

            .padding(CardGeometry.inset)
            .frame(
                maxWidth: .infinity,
                minHeight: min(minimumHeight, Self.tallestMinimumHeight),
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .background(card.color.rowFill, in: Self.shape)
            .overlay {
                if isDropTarget {
                    Self.shape.strokeBorder(Color.accent, lineWidth: 3)
                } else if colorSchemeContrast == .increased {
                    // With Increase Contrast each tile gets an edge, as the
                    // default grey alone barely parts it from the background.
                    Self.shape.strokeBorder(Color.primaryText, lineWidth: 1)
                }
            }
            .contentShape(Self.shape)
        }
        .buttonStyle(.plain)
        // The menu plays the system's haptic as it appears (A11Y-5).
        .contentShape(.contextMenuPreview, Self.shape)
        // Dragging is not the only way to reorder: the menu serves pointer,
        // keyboard, Voice Control and Switch Control, and the actions VoiceOver.
        .contextMenu {
            moveButtons
            if onMoveUp != nil || onMoveDown != nil {
                Divider()
            }
            deleteButton
        }
        // The name first, wherever the distance sits on the tile: "Joe's Market,
        // You're at Joe's Market Notting Hill" (A11Y-1).
        .accessibilityLabel(spokenLabel)
        .accessibilityActions {
            moveButtons
            deleteButton
        }
        // By the card's code, so UI tests find it in any language.
        .accessibilityIdentifier("cardRow_\(card.id)")
    }

    /// The name, or the name and then the distance as VoiceOver reads it.
    private var spokenLabel: Text {
        guard let proximity = card.proximity else { return Text(card.name) }
        return Text(
            "\(card.name), \(proximity.spokenDescription)",
            comment: """
                VoiceOver label for a card's tile on the Cards tab: the card's name, then how far away its nearest place is, \
                as in “Joe's Market, 350 metres from Joe's Market Notting Hill”.
                """
        )
    }

    /// Move Up and Move Down, where the card can move that way.
    @ViewBuilder
    private var moveButtons: some View {
        if let onMoveUp {
            Button(action: onMoveUp) {
                Label(
                    LocalizedStringResource("Move Up", comment: "Menu item and VoiceOver action that moves a card one place up the list."),
                    systemImage: "arrow.up"
                )
            }
            .accessibilityIdentifier("moveCardUpMenuItem")
        }
        if let onMoveDown {
            Button(action: onMoveDown) {
                Label(
                    LocalizedStringResource("Move Down", comment: "Menu item and VoiceOver action that moves a card one place down the list."),
                    systemImage: "arrow.down"
                )
            }
            .accessibilityIdentifier("moveCardDownMenuItem")
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
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
}

#if DEBUG
#Preview("Grid") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(CardSummary.samples) { card in
                CardTileView(card: card) {}
            }
        }
        .padding()
    }
}

#Preview("Long Card Name") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        CardTileView(card: CardSummary.longName) {}
        CardTileView(card: CardSummary.samples[0]) {}
    }
    .padding()
    Spacer()
}

#Preview("Drop target") {
    CardTileView(card: CardSummary.samples[0], isDropTarget: true) {}
        .frame(width: 180)
        .padding()
}
#endif
