import SwiftUI

/// Draws the picture Share Image sends (SHARE-2): the card face on its own, with
/// no copy button, no distance to the sharer's places and none of their notes
/// (CARD-14), in light appearance, at three times screen scale so the barcode
/// stays sharp enough to scan from another screen. The renderer starts from
/// SwiftUI's defaults rather than the screen's, so the face is given the
/// screen's language and direction: its date
/// and layout then match the card the sharer sees, and the barcode never mirrors.
@MainActor
enum CardShareImage {
    static let scale: CGFloat = 3
    /// In points; 1,080 pixels at `scale`.
    static let width: CGFloat = 360

    /// The PNG of `card`'s face, in `locale` and laid out in `layoutDirection`,
    /// or nil if it could not be drawn.
    static func png(of card: CardDetail, locale: Locale = .current, layoutDirection: LayoutDirection = .leftToRight) -> Data? {
        let renderer = ImageRenderer(
            content: face(of: card)
                .environment(\.locale, locale)
                .environment(\.layoutDirection, layoutDirection)
        )
        renderer.scale = scale
        return renderer.uiImage?.pngData()
    }

    /// The face as the picture shows it.
    static func face(of card: CardDetail) -> some View {
        CardFaceView(card: shared(card))
            .frame(width: width)
            // The default colour is a translucent grey over the screen; in a picture it sits on white.
            .background(.white, in: .rect(cornerRadius: CardGeometry.cornerRadius))
            .environment(\.colorScheme, .light)
            // BarcodeView draws its bars for the display scale, so draw them for the picture's.
            .environment(\.displayScale, scale)
    }

    /// `card` without where the sharer is or their notes, which are theirs to keep.
    private static func shared(_ card: CardDetail) -> CardDetail {
        CardDetail(
            id: card.id,
            name: card.name,
            code: card.code,
            barcodeType: card.barcodeType,
            timestamp: card.timestamp,
            color: card.color,
            icon: card.icon
        )
    }
}
