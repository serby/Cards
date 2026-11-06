import SwiftUI

/// A card in the grid on the Cards tab: its full colour, its icon, its name
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
    @Environment(\.distanceFormat) private var distanceFormat

    public init(card: CardSummary, isDropTarget: Bool = false, onTap: @escaping () -> Void, onDelete: @escaping () -> Void = {}) {
        self.card = card
        self.isDropTarget = isDropTarget
        self.onTap = onTap
        self.onDelete = onDelete
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
        // The name first, wherever the distance sits on the tile: "Joe's Market,
        // You're at Joe's Market Notting Hill" (A11Y-1).
        .accessibilityLabel(card.proximity.map { "\(card.name), \($0.spokenDescription(in: distanceFormat))" } ?? card.name)
        .accessibilityAction(named: Text("Delete"), onDelete)
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
