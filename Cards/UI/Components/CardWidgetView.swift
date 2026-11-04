import SwiftUI
import WidgetKit

/// The Home Screen widget's medium face: a card's name, how far away it is, and
/// its barcode, big enough to scan. Draws an empty state when there is no card.
/// The widget puts a refresh button in `accessory`; stories leave it empty.
public struct CardWidgetView<Accessory: View>: View {
    private let card: CardWidgetState?
    private let accessory: Accessory

    public init(card: CardWidgetState?, @ViewBuilder accessory: () -> Accessory) {
        self.card = card
        self.accessory = accessory()
    }

    public var body: some View {
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

    /// Name and distance above a full-width strip of bars.
    private func stripLayout(_ card: CardWidgetState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    title(card, lineLimit: 1)
                    proximity(card)
                }
                Spacer(minLength: 0)
                accessory
            }
            // About 4:1, the space a medium widget leaves under the name, so the bars use its full width.
            CardWidgetBarcode(card: card, pixelSize: CGSize(width: 900, height: 190), margin: 28)
        }
        .widgetCardStyle()
    }

    /// Name, distance and code beside a square code.
    private func squareLayout(_ card: CardWidgetState) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                title(card, lineLimit: 2)
                proximity(card)
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    Text(card.code)
                        .font(.caption.monospaced())
                        .lineLimit(2)
                        .foregroundStyle(card.color.secondaryInk)
                    Spacer(minLength: 0)
                    accessory
                }
            }
            CardWidgetBarcode(card: card, pixelSize: CGSize(width: 420, height: 420), margin: 24)
                .aspectRatio(1, contentMode: .fit)
        }
        .widgetCardStyle()
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
                .foregroundStyle(card.color.secondaryInk)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "barcode.viewfinder")
                .font(.title)
                .foregroundStyle(Color.accent)
                .widgetAccentable()
                .accessibilityHidden(true)
            Text("No cards yet")
                .font(.headline)
            Text("Add a card in Card Barcodes and it shows here.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
/// even on a tinted or clear Home Screen, so it always scans.
private struct CardWidgetBarcode: View {
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
            } else {
                Text("This code can't be drawn")
                    .font(.caption)
                    .foregroundStyle(Color(rgb: CardInk.dark.rgb))
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
    /// Reads as one element: "Tesco Clubcard, 120 m · Tesco Express".
    func widgetCardStyle() -> some View {
        accessibilityElement(children: .combine)
            .accessibilityHint("Opens the card in Card Barcodes")
    }
}
