import SwiftUI

/// The card palette as a grid of tappable swatches. Only palette colours can be
/// chosen, so the card's text always stays readable.
public struct CardColorPicker: View {
    @Binding private var selection: CardColor
    /// Swatches grow with the text size, so they stay easy to see and to hit.
    @ScaledMetric(relativeTo: .body) private var diameter = 34.0

    /// Column counts that divide the twelve colours into full rows, widest
    /// first.
    private static let columnCounts = [6, 4, 3, 2]
    private static let spacing = 8.0

    public init(selection: Binding<CardColor>) {
        _selection = selection
    }

    public var body: some View {
        // As many columns as fit with every swatch's full hit area, so targets
        // never overlap: six on most phones, fewer on narrow ones, in Slide Over
        // and at large text sizes.
        ViewThatFits(in: .horizontal) {
            ForEach(Self.columnCounts, id: \.self) { columns in
                grid(columns: columns)
            }
        }
        .padding(.vertical, 6)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Card colour", comment: "VoiceOver label for the grid of colour swatches in the card form."))
    }

    private func grid(columns: Int) -> some View {
        let colours = CardColor.allCases
        let rows = stride(from: 0, to: colours.count, by: columns).map { start in
            Array(colours[start..<min(start + columns, colours.count)])
        }
        return Grid(horizontalSpacing: Self.spacing, verticalSpacing: Self.spacing) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { color in
                        button(for: color)
                    }
                }
            }
        }
    }

    private func button(for color: CardColor) -> some View {
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
        .frame(maxWidth: .infinity)
    }

    /// One swatch. Internal rather than private so `SmartInvertTests` can
    /// look inside it.
    func swatch(for color: CardColor) -> some View {
        let isSelected = color == selection
        return Circle()
            .fill(color.cardFill)
            .overlay {
                if color == .standard {
                    Circle().strokeBorder(Color.separator)
                }
            }
            .frame(width: diameter, height: diameter)
            .overlay {
                if isSelected {
                    // Sized with the circle, so it never outgrows it.
                    Image(systemName: "checkmark")
                        .font(.system(size: diameter * 0.4, weight: .bold))
                        .foregroundStyle(color.primaryInk)
                        .accessibilityHidden(true)
                }
            }
            // The swatch shows the card as it will look, so Smart Invert must not
            // turn it into another colour.
            .keepsColoursWhenInverted()
            .padding(4)
            .overlay {
                Circle()
                    .strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.circle)
    }
}
