import SwiftUI

public extension View {
    /// Keeps the view's own colours when Smart Invert is on, for what must look
    /// as it is: a barcode, which many scanners cannot read inverted, and the
    /// card colours the user chose, which would otherwise show as their
    /// opposites (red as cyan). Classic Invert cannot be opted out of.
    func keepsColoursWhenInverted() -> some View {
        modifier(KeepsColoursWhenInverted())
    }
}

/// A named modifier rather than a bare `accessibilityIgnoresInvertColors()`,
/// so a test can find it in a view's body: nothing else can observe the flag.
struct KeepsColoursWhenInverted: ViewModifier {
    func body(content: Content) -> some View {
        content.accessibilityIgnoresInvertColors()
    }
}
