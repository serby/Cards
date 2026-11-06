import SwiftUI

/// The card symbols as a grid of tappable swatches, None first. Each swatch is
/// drawn on the card's colour in its ink, as the colour picker's are, so you
/// choose the symbol you will see.
public struct CardSymbolPicker: View {
    @Binding private var selection: String?
    private let color: CardColor
    private let onPick: () -> Void

    @ScaledMetric(relativeTo: .title3) private var swatchSize: CGFloat = 44

    /// `onPick` runs after each tap, so a sheet can close once a symbol is chosen.
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
            .accessibilityIdentifier("cardSymbol_none")

            ForEach(CardSymbol.all) { symbol in
                cell(symbol.name, label: symbol.label) {
                    Image(systemName: symbol.name)
                        .font(.title3)
                        .accessibilityHidden(true)
                }
                .accessibilityIdentifier("cardSymbol_\(symbol.name)")
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card symbol")
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
