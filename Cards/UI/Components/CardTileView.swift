import SwiftUI

/// A card in the grid on the Cards tab: its full colour, its symbol, its name
/// and how far away its nearest place is. VoiceOver reads it as one button,
/// the name and then the distance. A long press shows a menu with Delete.
public struct CardTileView: View {
    /// The tile's outline, for its fill and for the previews iOS lifts from it
    /// for the menu and for dragging.
    public static let shape = RoundedRectangle(cornerRadius: CardGeometry.cornerRadius)

    private let card: CardSummary
    /// Whether a card being dragged is over this one, and would take its place.
    private let isDropTarget: Bool
    private let onTap: () -> Void
    private let onDelete: () -> Void
    /// At least this tall, so a tile with a short name still looks like a card.
    /// It grows with the text, but only so far: at the largest sizes the text
    /// alone makes the tile tall enough.
    @ScaledMetric(relativeTo: .headline) private var minimumHeight: CGFloat = 112
    private static let tallestMinimumHeight: CGFloat = 200

    public init(card: CardSummary, isDropTarget: Bool = false, onTap: @escaping () -> Void, onDelete: @escaping () -> Void = {}) {
        self.card = card
        self.isDropTarget = isDropTarget
        self.onTap = onTap
        self.onDelete = onDelete
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                if let symbol = card.symbol {
                    // The name already says what the card is (CARD-12).
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(card.color.ink)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 0)
                Text(card.name)
                    .font(.headline)
                    .foregroundStyle(card.color.ink)
                    .multilineTextAlignment(.leading)
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
                }
            }
            .contentShape(Self.shape)
        }
        .buttonStyle(.plain)
        // The menu plays the system's haptic as it appears (A11Y-5).
        .contentShape(.contextMenuPreview, Self.shape)
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        // VoiceOver offers Delete in the actions rotor, as it did for the list's swipe.
        .accessibilityAction(named: Text("Delete"), onDelete)
    }
}
