import SwiftUI

/// The card face: its colour, with the name, the barcode, and the number and
/// date on white panels. The card screen shows it with a copy button beside the
/// number, and the card's places on a panel below (PLACE-9); anywhere else (a
/// shared image, the card at the top of the list) shows it as it is.
public struct CardFaceView<NumberAccessory: View, Footer: View>: View {
    private let card: CardDetail
    /// How wide `numberAccessory` is, so a matching space on the other side keeps
    /// the number centred on its panel.
    private let accessoryWidth: CGFloat
    private let numberAccessory: NumberAccessory
    /// Panels below the number's, in the same column; each takes `cardPanel()`.
    private let footer: Footer

    public init(
        card: CardDetail,
        accessoryWidth: CGFloat,
        @ViewBuilder numberAccessory: () -> NumberAccessory,
        @ViewBuilder footer: () -> Footer
    ) {
        self.card = card
        self.accessoryWidth = accessoryWidth
        self.numberAccessory = numberAccessory()
        self.footer = footer()
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        VStack(spacing: CardGeometry.inset) {
            VStack(spacing: 6) {
                nameAndSymbol

                if let proximity = card.proximity {
                    ProximityLabel(proximity, showsPlace: true)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CardPanel.secondaryInk)
                        .accessibilityIdentifier("cardProximityText")
                }
            }
            .cardPanel()

            BarcodeView(barcodeString: card.code, barcodeType: card.barcodeType)
                .accessibilityLabel("Barcode for \(card.name)")

            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: accessoryWidth, height: 1)
                        .accessibilityHidden(true)
                    Text(card.code)
                        .font(.title3.monospaced().weight(.semibold))
                        .foregroundStyle(CardPanel.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("cardCodeText")
                        .accessibilityLabel(Text("Card code: ") + Text(card.code).speechSpellsOutCharacters())
                        .accessibilityAddTraits(.isStaticText)
                    numberAccessory
                }

                Text("\(card.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(CardPanel.secondaryInk)
                    .accessibilityIdentifier("cardTimestampText")
                    .accessibilityLabel("Created on \(card.timestamp, format: Date.FormatStyle(date: .long, time: .shortened))")
                    .accessibilityAddTraits(.isStaticText)
            }
            .cardPanel()

            footer
        }
        .padding(CardGeometry.inset)
        .frame(maxWidth: .infinity)
        .background(card.color.cardFill, in: .rect(cornerRadius: CardGeometry.cornerRadius))
    }

    /// The name, with the card's symbol beside it, or above it at the
    /// accessibility text sizes. VoiceOver reads only the name, which already
    /// says what the card is.
    private var nameAndSymbol: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            if let symbol = card.symbol {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
            }
            Text(card.name)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("cardNameText")
                .accessibilityLabel("Card name: \(card.name)")
                .accessibilityAddTraits(.isHeader)
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
