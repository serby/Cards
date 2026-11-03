import SwiftUI

/// The card palette as a grid of tappable swatches. Only palette colours can be
/// chosen, so the card's text always stays readable.
public struct CardColorPicker: View {
    @Binding private var selection: CardColor

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
                .accessibilityLabel(Text(color.displayName))
                .accessibilityAddTraits(color == selection ? .isSelected : [])
                .accessibilityIdentifier("cardColor_\(color.rawValue)")
            }
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
            .frame(width: 34, height: 34)
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.footnote.bold())
                        .foregroundStyle(color.primaryInk)
                        .accessibilityHidden(true)
                }
            }
            .padding(4)
            .overlay {
                Circle()
                    .strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.circle)
    }
}
