import CoreGraphics

/// Callbacks the scanner's controls raise. Defaults are no-ops so stories and
/// previews can supply only the ones they care about.
@MainActor
public struct ScannerActions {
    /// A tap to focus, at this point in the scanner's own coordinates.
    public var focus: (CGPoint) -> Void
    /// The torch button, asking for the torch on (true) or off.
    public var setTorch: (Bool) -> Void
    /// A pinch, with how far it has spread since it began: 2 is twice as far apart.
    public var pinch: (CGFloat) -> Void
    /// The pinch ended.
    public var endPinch: () -> Void

    public init(
        focus: @escaping (CGPoint) -> Void = { _ in },
        setTorch: @escaping (Bool) -> Void = { _ in },
        pinch: @escaping (CGFloat) -> Void = { _ in },
        endPinch: @escaping () -> Void = {}
    ) {
        self.focus = focus
        self.setTorch = setTorch
        self.pinch = pinch
        self.endPinch = endPinch
    }
}
