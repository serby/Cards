import SwiftUI

public extension View {
    /// Keeps a card face, and what sits with it, no wider than
    /// `CardGeometry.maximumWidth`, centred in the space it is given, so an iPad,
    /// an unfolded iPhone Duo or a phone on its side shows the card as a phone
    /// does upright (CARD-4).
    func cardColumn() -> some View {
        frame(maxWidth: CardGeometry.maximumWidth)
            .frame(maxWidth: .infinity)
    }

    /// For a list holding a card face: insets its rows to the card's column on
    /// a screen wide enough to need it, and leaves the list's own margins on a
    /// narrower one (CARD-4).
    func cardColumnMargins() -> some View {
        modifier(CardColumnMargins())
    }
}

private struct CardColumnMargins: ViewModifier {
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    /// Half the room beside the column, or nil for the list's own margins
    /// where the column already fills the width between them.
    private var margin: CGFloat? {
        let beside = (width - CardGeometry.maximumWidth) / 2
        return beside > Self.listMargin ? beside : nil
    }

    /// About what an inset grouped list leaves at each side.
    private static let listMargin: CGFloat = 20
}
