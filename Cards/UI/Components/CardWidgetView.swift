import SwiftUI
import WidgetKit

/// The Home Screen widget's medium face: a card's name, how far away it is, and
/// its barcode, big enough to scan. Draws an empty state when there is no card.
/// The widget puts a refresh button in `accessory`; stories leave it empty.
public struct CardWidgetView<Accessory: View>: View {
    /// The widget is a fixed size, so text grows only this far: beyond it the
    /// name and distance would leave the barcode too small to scan. The card's
    /// own screen shows them at every size.
    static var largestTextSize: DynamicTypeSize { .xxLarge }

    private let card: CardWidgetState?
    private let accessory: Accessory
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public init(card: CardWidgetState?, @ViewBuilder accessory: () -> Accessory) {
        self.card = card
        self.accessory = accessory()
    }

    public var body: some View {
        Group {
            if let card {
                if card.barcodeType.isSquare {
                    squareLayout(card)
                } else {
                    stripLayout(card)
                }
            } else {
                emptyState
            }
        }
        .dynamicTypeSize(...Self.largestTextSize)
    }

    /// Name and distance above a full-width strip of bars.
    private func stripLayout(_ card: CardWidgetState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    title(card, lineLimit: 1)
                    proximity(card)
                }
                .widgetCardDescription()
                Spacer(minLength: 0)
                accessory
            }
            // About 4:1, the space a medium widget leaves under the name, so the bars use its full width.
            CardWidgetBarcode(card: card, pixelSize: CGSize(width: 900, height: 190), margin: 28)
                .keepsColoursWhenInverted()
        }
    }

    /// Name, distance and code beside a square code.
    private func squareLayout(_ card: CardWidgetState) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 4) {
                    title(card, lineLimit: 2)
                    proximity(card)
                }
                .widgetCardDescription()
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    code(card)
                    Spacer(minLength: 0)
                    accessory
                }
            }
            CardWidgetBarcode(card: card, pixelSize: CGSize(width: 420, height: 420), margin: 24)
                .aspectRatio(1, contentMode: .fit)
                .keepsColoursWhenInverted()
        }
    }

    private func title(_ card: CardWidgetState, lineLimit: Int) -> some View {
        Text(card.name)
            .font(.headline)
            .lineLimit(lineLimit)
            .foregroundStyle(card.color.primaryInk)
            .widgetAccentable()
    }

    @ViewBuilder
    private func proximity(_ card: CardWidgetState) -> some View {
        if let proximity = card.proximity {
            ProximityLabel(proximity, showsPlace: true)
                .font(.caption.weight(.medium))
                .foregroundStyle(supportingInk(card))
        }
    }

    /// The code as it is written, left to right in every language, and spelled
    /// out by VoiceOver, as on the card's screen.
    private func code(_ card: CardWidgetState) -> some View {
        Text(card.code)
            .font(.caption.monospaced())
            .lineLimit(2)
            .foregroundStyle(supportingInk(card))
            .readsLeftToRight()
            .accessibilityLabel(
                Text(
                    "Card code: \(Text(card.code).speechSpellsOutCharacters())",
                    comment: """
                        VoiceOver label for a card's code, shown with its barcode on the card's screen and in the Home Screen widget. \
                        VoiceOver spells the code out character by character.
                        """
                )
            )
    }

    /// The distance and the code: a lighter ink, or with Increase Contrast the
    /// full ink of the name, as on the card's screen.
    private func supportingInk(_ card: CardWidgetState) -> Color {
        colorSchemeContrast == .increased ? card.color.primaryInk : card.color.secondaryInk
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "barcode.viewfinder")
                .font(.title)
                .foregroundStyle(Color.accent)
                .widgetAccentable()
                .accessibilityHidden(true)
            Text("No cards yet", comment: "Title of the Home Screen widget before the user has added a card.")
                .font(.headline)
            Text(
                "Add a card in Card Barcodes and it shows here.",
                comment: "Under “No cards yet” in the Home Screen widget. Card Barcodes is the app's name."
            )
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

public extension CardWidgetView where Accessory == EmptyView {
    init(card: CardWidgetState?) {
        self.init(card: card) { EmptyView() }
    }
}

/// The code on white with its quiet zone, as one image that stays full colour
/// even on a tinted or clear Home Screen, so it always scans. It never mirrors
/// right to left, as a mirrored barcode will not scan.
struct CardWidgetBarcode: View {
    let card: CardWidgetState
    let pixelSize: CGSize
    let margin: CGFloat

    var body: some View {
        Group {
            if let image = BarcodeImage.onWhite(card.code, type: card.barcodeType, size: pixelSize, margin: margin) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFit()
                    .flipsForRightToLeftLayoutDirection(false)
            } else {
                Text(
                    "This code can't be drawn",
                    comment: "Shown in the Home Screen widget instead of the barcode when the card's code can't be drawn in its barcode format."
                )
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(rgb: CardInk.dark.rgb))
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white)
            }
        }
        .clipShape(.rect(cornerRadius: 10))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

private extension View {
    /// The name and distance read as one element, "Tesco Clubcard, 120 metres
    /// from Tesco Express", which says what tapping the widget does. The
    /// refresh button stays an element of its own.
    func widgetCardDescription() -> some View {
        accessibilityElement(children: .combine)
            .accessibilityHint(
                Text(
                    "Opens the card in Card Barcodes",
                    comment: "VoiceOver hint for the card in the Home Screen widget. Card Barcodes is the app's name."
                )
            )
    }
}
