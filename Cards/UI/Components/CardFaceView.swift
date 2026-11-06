import SwiftUI

/// The card face: its colour, with the name, the barcode, and the number and
/// date on white panels. The card screen shows it with a copy button beside the
/// number; anywhere else (a shared image, the card at the top of the list) shows
/// it as it is.
public struct CardFaceView<NumberAccessory: View>: View {
    private let card: CardDetail
    /// How wide `numberAccessory` is, so a matching space on the other side keeps
    /// the number centred on its panel.
    private let accessoryWidth: CGFloat
    private let numberAccessory: NumberAccessory

    public init(card: CardDetail, accessoryWidth: CGFloat, @ViewBuilder numberAccessory: () -> NumberAccessory) {
        self.card = card
        self.accessoryWidth = accessoryWidth
        self.numberAccessory = numberAccessory()
    }

    public var body: some View {
        VStack(spacing: CardGeometry.inset) {
            VStack(spacing: 6) {
                Text(card.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(CardPanel.ink)
                    .accessibilityIdentifier("cardNameText")
                    .accessibilityLabel("Card name: \(card.name)")
                    .accessibilityAddTraits(.isHeader)

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
        }
        .padding(CardGeometry.inset)
        .frame(maxWidth: .infinity)
        .background(card.color.cardFill, in: .rect(cornerRadius: CardGeometry.cornerRadius))
    }
}

public extension CardFaceView where NumberAccessory == EmptyView {
    /// The face with nothing beside the number.
    init(card: CardDetail) {
        self.init(card: card, accessoryWidth: 0) { EmptyView() }
    }
}

private extension View {
    /// A white panel for text on the card face, its corners nested inside the card's.
    func cardPanel() -> some View {
        padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(CardPanel.fill, in: .rect(cornerRadius: CardGeometry.panelCornerRadius))
    }
}
