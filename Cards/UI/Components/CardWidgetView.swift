import SwiftUI
import WidgetKit

/// The Home Screen widget's medium face: a card's name, how far away it is, and
/// its barcode, big enough to scan. Draws an empty state when there is no card.
/// The widget puts a refresh button in `accessory`; stories leave it empty.
public struct CardWidgetView<Accessory: View>: View {
    private let card: CardWidgetState?
    private let accessory: Accessory

    /// Full colour on a normal Home Screen; tinted or clear Home Screens draw
    /// everything in one tint, where white panels would hide the text.
    @Environment(\.widgetRenderingMode) private var renderingMode

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

    private var isFullColor: Bool { renderingMode == .fullColor }

    /// Name and distance on a panel above a full-width strip of bars.
    private func stripLayout(_ card: CardWidgetState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    title(card, lineLimit: 1)
                    proximity(card)
                }
                Spacer(minLength: 0)
                accessory
            }
            .widgetPanel(isFullColor)
            // About 4:1, the space a medium widget leaves under the name, so the bars use its full width.
            CardWidgetBarcode(card: card, pixelSize: CGSize(width: 900, height: 190), margin: 28)
        }
        .widgetCardStyle()
    }

    /// Name, distance and code on a panel beside a square code.
    private func squareLayout(_ card: CardWidgetState) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                title(card, lineLimit: 2)
                proximity(card)
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    Text(card.code)
                        .font(.caption.monospaced())
                        .lineLimit(2)
                        .foregroundStyle(secondaryInk)
                    Spacer(minLength: 0)
                    accessory
                }
            }
            .widgetPanel(isFullColor)
            CardWidgetBarcode(card: card, pixelSize: CGSize(width: 420, height: 420), margin: 24)
                .aspectRatio(1, contentMode: .fit)
        }
        .widgetCardStyle()
    }

    private var ink: AnyShapeStyle {
        isFullColor ? AnyShapeStyle(CardPanel.ink) : AnyShapeStyle(.primary)
    }

    private var secondaryInk: AnyShapeStyle {
        isFullColor ? AnyShapeStyle(CardPanel.secondaryInk) : AnyShapeStyle(.secondary)
    }

    private func title(_ card: CardWidgetState, lineLimit: Int) -> some View {
        Text(card.name)
            .font(.headline)
            .lineLimit(lineLimit)
            .foregroundStyle(ink)
            .widgetAccentable()
    }

    @ViewBuilder
    private func proximity(_ card: CardWidgetState) -> some View {
        if let proximity = card.proximity {
            ProximityLabel(proximity, showsPlace: true)
                .font(.caption.weight(.medium))
                .foregroundStyle(secondaryInk)
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
                    .foregroundStyle(CardPanel.ink)
            }
        }
        // A white panel that fills the space, so its edges line up with the text
        // panel's, with its corners nested in the widget's own.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CardPanel.fill, in: ContainerRelativeShape())
        .clipShape(ContainerRelativeShape())
        .accessibilityHidden(true)
    }
}

private extension View {
    /// The white panel text sits on, its corners nested in the widget's. Left out
    /// on tinted Home Screens, which draw the text in the tint instead.
    func widgetPanel(_ isFullColor: Bool) -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(isFullColor ? CardPanel.fill : .clear, in: ContainerRelativeShape())
    }

    /// Reads as one element: "Tesco Clubcard, 120 m · Tesco Express".
    func widgetCardStyle() -> some View {
        accessibilityElement(children: .combine)
            .accessibilityHint("Opens the card in Card Barcodes")
    }
}

#if DEBUG
// This file is also built into the widget extension, which has none of
// Cards/Development, so these previews carry their own data.
#Preview("Nearby") {
    CardWidgetView(card: CardWidgetState(
        name: "Tesco Clubcard",
        code: "5012345678900",
        barcodeType: .ean13,
        color: .blue,
        proximity: CardProximity(placeName: "Tesco Express", distance: 120)
    ))
    .previewWidgetFrame(.blue)
}

#Preview("QR code") {
    CardWidgetView(card: CardWidgetState(name: "Westway Climbing", code: "https://serby.net", barcodeType: .qrCode, color: .graphite))
        .previewWidgetFrame(.graphite)
}

#Preview("No cards") {
    CardWidgetView(card: nil)
        .previewWidgetFrame(.standard)
}

private extension View {
    /// The medium widget's size and corners, as WidgetKit draws it.
    func previewWidgetFrame(_ color: CardColor) -> some View {
        padding(16)
            .frame(width: 338, height: 158)
            .background(color.widgetFill, in: .rect(cornerRadius: 22))
            .containerShape(.rect(cornerRadius: 22))
    }
}
#endif
