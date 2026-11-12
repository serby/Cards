import CoreGraphics

/// Corner radii that nest. Anything inset into a rounded shape takes the outer
/// radius minus the inset, so its curve runs parallel to the outer one instead
/// of looking pinched or bloated (see docs/STYLE.md, "Corners nest").
public enum CardGeometry {
    /// The card face.
    public static let cornerRadius: CGFloat = 28
    /// From the card's edge to its panels, and between panels.
    public static let inset: CGFloat = 16
    /// The panels on a card face: the text and the barcode's frame.
    public static let panelCornerRadius = cornerRadius - inset
    /// The barcode's translucent frame, around the white the bars sit on.
    public static let barcodeFrame: CGFloat = 6
    /// The white inside the barcode's frame.
    public static let barcodeCornerRadius = panelCornerRadius - barcodeFrame
    /// From the edge of that white to the barcode on it.
    public static let barcodePlatePadding: CGFloat = 16

    /// The widest a barcode or QR code is drawn, in points. `BarcodeView`
    /// draws its image this wide, so a wider one would only scale its pixels
    /// up, and a QR code would grow taller than a scanner needs.
    public static let maximumBarcodeWidth: CGFloat = 400
    /// The widest a card face is: its barcode at its widest, with the white,
    /// the frame and the card's inset round it. Every screen that shows a face
    /// keeps it, and what sits with it, to this width with `cardColumn()`.
    public static let maximumWidth = maximumBarcodeWidth + 2 * (barcodePlatePadding + barcodeFrame + inset)
}
