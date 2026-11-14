import SwiftUI

/// A card's screen on the watch (WATCH-3): its name, its barcode across the
/// screen on white, and its code underneath, on the card's colour as on the
/// phone. Text on the colour is in the colour's ink (docs/STYLE.md).
struct WatchCardView: View {
    let card: WatchCard

    /// How much of the screen's height a square code takes.
    static let squareShare: CGFloat = 0.7

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                barcode
                code
            }
            .foregroundStyle(card.color.ink)
        }
        // In the bar at the top, beside Back, which leaves the screen to the code.
        .navigationTitle(card.name)
        // In the colour's ink, as all text on the colour is; the bar's own grey failed contrast.
        .toolbarForegroundStyle(card.color.ink, for: .navigationBar)
        .containerBackground(card.color.widgetFill, for: .navigation)
        .accessibilityIdentifier("watchCardView")
    }

    /// The barcode across the screen, or a square code no taller than most of
    /// the screen, so all of it shows without scrolling, as a scanner needs.
    @ViewBuilder
    private var barcode: some View {
        let barcode = WatchBarcodeView(modules: card.modules, type: card.barcodeType)
        if card.barcodeType.isSquare {
            barcode.containerRelativeFrame(.vertical) { height, _ in height * Self.squareShare }
        } else {
            barcode
        }
    }

    /// The code as it is written, left to right in every language, and spelled
    /// out by VoiceOver, as on the phone.
    private var code: some View {
        Text(card.code)
            .font(.caption.monospaced())
            .multilineTextAlignment(.center)
            .readsLeftToRight()
            .accessibilityLabel(
                Text(
                    "Card code: \(Text(card.code).speechSpellsOutCharacters())",
                    comment: """
                        VoiceOver label for a card's code under its barcode on Apple Watch. \
                        VoiceOver spells the code out character by character.
                        """
                )
            )
    }
}

#if DEBUG
#Preview("Strip barcode") {
    NavigationStack {
        WatchCardView(card: .joesMarket)
    }
}

#Preview("QR code") {
    NavigationStack {
        WatchCardView(card: .boulderBarn)
    }
}

#Preview("Cannot be drawn") {
    NavigationStack {
        WatchCardView(card: .ladbrokeLibrary)
    }
}
#endif
