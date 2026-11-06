import SwiftUI

/// The card palette as a grid of tappable swatches, ending with the system colour
/// picker for any other colour. Card text sits on white panels, so every colour
/// keeps it readable.
public struct CardColorPicker: View {
    @Binding private var selection: CardColor
    /// Swatches grow with the text size, so they stay easy to see and to hit.
    @ScaledMetric(relativeTo: .body) private var diameter = 34.0

    /// Column counts that divide the palette and the custom well into full
    /// rows, widest first.
    private static let columnCounts = [6, 4, 3, 2]
    private static let spacing = 8.0

    /// The system colour well's own size, which it is scaled from to match the
    /// swatches.
    private static let systemWellSize: CGFloat = 28

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

    /// The palette, then the custom well, which is the `nil` cell.
    private func grid(columns: Int) -> some View {
        let cells: [CardColor?] = CardColor.allCases.map(Optional.some) + [nil]
        let rows = stride(from: 0, to: cells.count, by: columns).map { start in
            Array(cells[start..<min(start + columns, cells.count)])
        }
        return Grid(horizontalSpacing: Self.spacing, verticalSpacing: Self.spacing) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { cell in
                        if let color = cell {
                            button(for: color)
                        } else {
                            customSwatch
                                .frame(maxWidth: .infinity)
                        }
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
                        .foregroundStyle(color.ink)
                        .accessibilityHidden(true)
                }
            }
            // The swatch shows the card as it will look, so Smart Invert must not
            // turn it into another colour.
            .keepsColoursWhenInverted()
            .selectionRing(isSelected)
    }

    /// The last cell: the system colour well, showing the card's colour, which
    /// opens the full colour picker.
    private var customSwatch: some View {
        ColorPicker(selection: customColor, supportsOpacity: false) {
            Text(
                "Custom colour",
                comment: """
                    VoiceOver label for the last swatch in the card form's colour grid, \
                    which opens the system colour picker to choose any colour.
                    """
            )
        }
        .labelsHidden()
        .scaleEffect(diameter / Self.systemWellSize)
        .frame(width: diameter, height: diameter)
        .keepsColoursWhenInverted()
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

#if DEBUG
#Preview {
    @Previewable @State var color = CardColor.blue
    Form {
        Section {
            CardColorPicker(selection: $color)
        } header: {
            Text(verbatim: "Colour")
        }
    }
}
#endif
