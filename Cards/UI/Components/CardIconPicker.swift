import SwiftUI

/// The card icons as a grid of tappable swatches, None first and then each
/// group under its heading. Each swatch is drawn on the card's colour in its
/// ink, as the colour picker's are, so you choose the icon you will see. Each
/// swatch has its icon's name as its id, so a scroll view can go to the chosen
/// one with `ScrollViewProxy.scrollTo`.
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
            Section {
                cell(nil, label: noIcon) {
                    noIcon
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .accessibilityIdentifier("cardIcon_none")
            }

            ForEach(CardIcon.groups) { group in
                Section {
                    ForEach(group.icons) { icon in
                        cell(icon.name, label: Text(icon.label)) {
                            Image(systemName: icon.name)
                                .font(.title3)
                                .accessibilityHidden(true)
                        }
                        .id(icon.name)
                        .accessibilityIdentifier("cardIcon_\(icon.name)")
                    }
                } header: {
                    // A heading, so the VoiceOver rotor moves from group to group.
                    Text(group.title)
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Card icon", comment: "VoiceOver label for the grid of icons in the card icon picker."))
    }

    /// The first choice, for a card without an icon: shown in its circle and
    /// read by VoiceOver.
    private var noIcon: Text {
        Text(
            "None",
            comment: "First choice in the card icon picker, for a card with no icon, and read by VoiceOver. Keep it short: it fits in a small circle."
        )
    }

    private func cell<Content: View>(_ name: String?, label: Text, @ViewBuilder content: () -> Content) -> some View {
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
    ScrollView {
        CardIconPicker(selection: $icon, color: .blue)
            .padding()
    }
}

#Preview("Basket chosen") {
    @Previewable @State var icon: String? = "basket.fill"
    ScrollView {
        CardIconPicker(selection: $icon, color: .teal)
            .padding()
    }
}

#Preview("Largest text") {
    @Previewable @State var icon: String? = "pills.fill"
    ScrollView {
        CardIconPicker(selection: $icon, color: .indigo)
            .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
