import SwiftUI

/// The card face: its colour, with the name, the barcode, and the number and
/// date on white panels. The card screen shows it with a copy button beside the
/// number, the place in the top panel opening in Maps (PLACE-6), and the card's
/// places on a panel below (PLACE-9); anywhere else (a shared image, the card at
/// the top of the list) shows it as it is.
public struct CardFaceView<NumberAccessory: View, Footer: View>: View {
    private let card: CardDetail
    /// How wide `numberAccessory` is, so a matching space on the other side keeps
    /// the number centred on its panel.
    private let accessoryWidth: CGFloat
    /// Moves VoiceOver to the card's name, for a screen that opens on the card.
    private let nameFocus: AccessibilityFocusState<Bool>.Binding?
    /// Whether the place in the top panel opens in Maps, as on the card screen.
    private let linksNearestPlace: Bool
    private let numberAccessory: NumberAccessory
    /// Panels below the number's, in the same column; each takes `cardPanel()`.
    private let footer: Footer

    public init(
        card: CardDetail,
        accessoryWidth: CGFloat,
        nameFocus: AccessibilityFocusState<Bool>.Binding? = nil,
        linksNearestPlace: Bool = false,
        @ViewBuilder numberAccessory: () -> NumberAccessory,
        @ViewBuilder footer: () -> Footer
    ) {
        self.card = card
        self.accessoryWidth = accessoryWidth
        self.nameFocus = nameFocus
        self.linksNearestPlace = linksNearestPlace
        self.numberAccessory = numberAccessory()
        self.footer = footer()
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    /// The code and its accessory side by side, or stacked at the accessibility sizes.
    private var numberLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 0))
    }

    /// The place and the date: a lighter ink, or with Increase Contrast the
    /// full ink of the name and code.
    private var supportingInk: Color {
        colorSchemeContrast == .increased ? CardPanel.ink : CardPanel.secondaryInk
    }

    public var body: some View {
        VStack(spacing: CardGeometry.inset) {
            VStack(spacing: 6) {
                nameAndIcon

                if let proximity = card.proximity {
                    if linksNearestPlace, let url = card.nearestPlaceMapsURL {
                        Link(destination: url) {
                            proximityLabel(proximity)
                                // Tall enough to tap at every text size, by
                                // reaching into the space round it rather than
                                // moving anything: the padding is taken back below.
                                .padding(.vertical, Self.linkReach)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, -Self.linkReach)
                        .accessibilityHint(Text.opensPlaceInMaps)
                        .accessibilityIdentifier("cardProximityText")
                    } else {
                        proximityLabel(proximity)
                            .accessibilityIdentifier("cardProximityText")
                            // Its own label replaces the text's, and with it the
                            // static text trait, which left the accessibility
                            // audit taking it for an 18 pt tall control.
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
            }
            .cardPanel()

            // It says itself that it is a barcode, and of which type.
            BarcodeView(barcodeString: card.code, barcodeType: card.barcodeType)

            // Centred like the name above when they wrap, as at the largest
            // text sizes, rather than each line at the leading edge.
            VStack(spacing: 4) {
                // Beside the code, with a matching space on the other side, or
                // under it at the accessibility sizes, where the grown accessory
                // would run into the code's wrapped lines.
                numberLayout {
                    if !dynamicTypeSize.isAccessibilitySize {
                        Color.clear
                            .frame(width: accessoryWidth, height: 1)
                            .accessibilityHidden(true)
                    }
                    Text(card.code)
                        .font(.title3.monospaced().weight(.semibold))
                        .foregroundStyle(CardPanel.ink)
                        .multilineTextAlignment(.center)
                        .readsLeftToRight()
                        .frame(maxWidth: .infinity)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("cardCodeText")
                        .accessibilityLabel(
                            Text(
                                "Card code: \(Text(card.code).speechSpellsOutCharacters())",
                                comment: """
                                    VoiceOver label for a card's code, shown with its barcode on the card's screen and in the Home Screen \
                                    widget. VoiceOver spells the code out character by character.
                                    """
                            )
                        )
                        .accessibilityAddTraits(.isStaticText)
                    numberAccessory
                }

                Text(card.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(supportingInk)
                    .accessibilityIdentifier("cardTimestampText")
                    .accessibilityLabel(
                        Text(
                            "Created on \(card.timestamp, format: Date.FormatStyle(date: .long, time: .shortened))",
                            comment: "VoiceOver label for when the card was added. The argument is a date and time: 14 November 2023 at 22:13."
                        )
                    )
                    .accessibilityAddTraits(.isStaticText)
            }
            .cardPanel()

            footer
        }
        .padding(CardGeometry.inset)
        .frame(maxWidth: .infinity)
        .background(card.color.cardFill, in: .rect(cornerRadius: CardGeometry.cornerRadius))
        // With Increase Contrast the card gets an edge: the default grey card
        // is barely lighter than the screen behind it.
        .overlay {
            if colorSchemeContrast == .increased {
                RoundedRectangle(cornerRadius: CardGeometry.cornerRadius).strokeBorder(Color.primaryText, lineWidth: 1)
            }
        }
        .keepsColoursWhenInverted()
    }

    /// How far the place's link reaches above and below its text, so it is at
    /// least 44 points tall: into the gap below the name and the panel's padding.
    private static var linkReach: CGFloat { 13 }

    /// The distance and the place, shown whole at every size and centred like
    /// the name above when it wraps: on one line it was cut off at the larger
    /// text sizes.
    private func proximityLabel(_ proximity: CardProximity) -> some View {
        ProximityLabel(proximity, showsPlace: true, wraps: true)
            .multilineTextAlignment(.center)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(supportingInk)
    }

    /// The name, with the card's icon beside it, or above it at the
    /// accessibility text sizes. VoiceOver reads only the name, which already
    /// says what the card is.
    private var nameAndIcon: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            if let icon = card.icon {
                Image(systemName: icon)
                    .accessibilityHidden(true)
            }
            Text(card.name)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("cardNameText")
                // The name alone, so the headings rotor lists cards by name.
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused(ifGiven: nameFocus)
        }
        .font(.title2.bold())
        .foregroundStyle(CardPanel.ink)
    }
}

public extension CardFaceView where Footer == EmptyView {
    /// The face with nothing below the number.
    init(card: CardDetail, accessoryWidth: CGFloat, @ViewBuilder numberAccessory: () -> NumberAccessory) {
        self.init(card: card, accessoryWidth: accessoryWidth, numberAccessory: numberAccessory) { EmptyView() }
    }
}

public extension CardFaceView where NumberAccessory == EmptyView, Footer == EmptyView {
    /// The face with nothing beside or below the number.
    init(card: CardDetail) {
        self.init(card: card, accessoryWidth: 0) { EmptyView() }
    }
}

extension View {
    /// A white panel for text on the card face, its corners nested inside the card's.
    func cardPanel() -> some View {
        padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(CardPanel.fill, in: .rect(cornerRadius: CardGeometry.panelCornerRadius))
    }
}

private extension View {
    /// Takes VoiceOver focus through `binding`, when there is one.
    @ViewBuilder
    func accessibilityFocused(ifGiven binding: AccessibilityFocusState<Bool>.Binding?) -> some View {
        if let binding {
            accessibilityFocused(binding)
        } else {
            self
        }
    }
}

#if DEBUG
#Preview("Barcode") {
    CardFaceView(card: .sample)
        .padding()
}

#Preview("QR code") {
    CardFaceView(card: .qr)
        .padding()
}

#Preview("With copy button") {
    CardFaceView(card: .sample, accessoryWidth: 44) {
        Image(systemName: "doc.on.doc")
            .foregroundStyle(CardPanel.secondaryInk)
            .frame(width: 44, height: 44)
    }
    .padding()
}
#endif
