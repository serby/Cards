import CoreGraphics

/// Corner radii that nest. Anything inset into a rounded shape takes the outer
/// radius minus the inset, so its curve runs parallel to the outer one instead
/// of looking pinched or bloated (see docs/STYLE.md, "Corners nest").
public enum CardGeometry {
    /// The card face.
    public static let cornerRadius: CGFloat = 28
    /// From the card's edge to its panels, and between panels.
    public static let inset: CGFloat = 12
    /// The panels on a card face: the text and the barcode's frame.
    public static let panelCornerRadius = cornerRadius - inset
    /// The barcode's translucent frame, around the white the bars sit on.
    public static let barcodeFrame: CGFloat = 6
    /// The white inside the barcode's frame.
    public static let barcodeCornerRadius = panelCornerRadius - barcodeFrame
}
