import SwiftUI

/// The card palette as a grid of tappable swatches, ending with the system colour
/// picker for any other colour. Card text sits on white panels, so every colour
/// keeps it readable.
public struct CardColorPicker: View {
    @Binding private var selection: CardColor

    /// The swatches' size, which the colour picker's well is scaled to match.
    private static let swatchSize: CGFloat = 34
    private static let systemWellSize: CGFloat = 28

    public init(selection: Binding<CardColor>) {
        _selection = selection
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(CardColor.allCases, id: \.self) { color in
                Button {
                    selection = color
                } label: {
                    swatch(for: color)
                }
                // Plain style gives each swatch its own hit area inside a Form row.
                .buttonStyle(.plain)
                .accessibilityLabel(color.displayName)
                .accessibilityAddTraits(color == selection ? .isSelected : [])
                .accessibilityIdentifier("cardColor_\(color.rawValue)")
            }
            customSwatch
        }
        .padding(.vertical, 6)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card colour")
    }

    private func swatch(for color: CardColor) -> some View {
        let isSelected = color == selection
        return Circle()
            .fill(color.cardFill)
            .overlay {
                if color == .standard {
                    Circle().strokeBorder(Color.separator)
                }
            }
            .frame(width: Self.swatchSize, height: Self.swatchSize)
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.footnote.bold())
                        .foregroundStyle(color.ink)
                        .accessibilityHidden(true)
                }
            }
            .selectionRing(isSelected)
    }

    /// The last cell: the system colour well, showing the card's colour, which
    /// opens the full colour picker.
    private var customSwatch: some View {
        ColorPicker(selection: customColor, supportsOpacity: false) {
            Text("Custom colour")
        }
        .labelsHidden()
        .scaleEffect(Self.swatchSize / Self.systemWellSize)
        .frame(width: Self.swatchSize, height: Self.swatchSize)
        .selectionRing(selection.isCustom)
        .accessibilityAddTraits(selection.isCustom ? .isSelected : [])
        .accessibilityIdentifier("cardColor_custom")
    }

    private var customColor: Binding<Color> {
        Binding(
            get: { selection.backgroundColor ?? .white },
            set: { selection = .custom(from: $0) }
        )
    }
}

private extension View {
    /// The ring round the chosen swatch, and a 44-point hit area.
    func selectionRing(_ isSelected: Bool) -> some View {
        padding(4)
            .overlay {
                Circle()
                    .strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.circle)
    }
}
