import SwiftUI

/// The card icons as a grid of tappable swatches, None first. Each swatch is
/// drawn on the card's colour in its ink, as the colour picker's are, so you
/// choose the icon you will see.
public struct CardIconPicker: View {
    @Binding private var selection: String?
    private let color: CardColor
    private let onPick: () -> Void

    @ScaledMetric(relativeTo: .title3) private var swatchSize: CGFloat = 44

    /// `onPick` runs after each tap, so a sheet can close once an icon is chosen.
    public init(selection: Binding<String?>, color: CardColor = .standard, onPick: @escaping () -> Void = {}) {
        _selection = selection
        self.color = color
        self.onPick = onPick
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: swatchSize + 8), spacing: 8)], spacing: 8) {
            cell(nil, label: "None") {
                Text("None")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .accessibilityIdentifier("cardIcon_none")

            ForEach(CardIcon.all) { icon in
                cell(icon.name, label: icon.label) {
                    Image(systemName: icon.name)
                        .font(.title3)
                        .accessibilityHidden(true)
                }
                .accessibilityIdentifier("cardIcon_\(icon.name)")
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card icon")
    }

    private func cell<Content: View>(_ name: String?, label: String, @ViewBuilder content: () -> Content) -> some View {
        let isSelected = name == selection
        return Button {
            selection = name
            onPick()
        } label: {
            Circle()
                .fill(color.cardFill)
                .overlay {
                    if color == .standard {
                        Circle().strokeBorder(Color.separator)
                    }
                }
                .overlay { content().foregroundStyle(color.ink).padding(4) }
                .frame(width: swatchSize, height: swatchSize)
                .padding(4)
                .overlay {
                    Circle().strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2)
                }
                .contentShape(.circle)
        }
        // Plain style gives each swatch its own hit area, as in the colour picker.
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview("None chosen") {
    @Previewable @State var icon: String?
    CardIconPicker(selection: $icon, color: .blue)
}

#Preview("Basket chosen") {
    @Previewable @State var icon: String? = "basket.fill"
    CardIconPicker(selection: $icon, color: .teal)
}
#endif
