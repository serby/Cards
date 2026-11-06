import CoreGraphics

/// What the scanner's controls show over the camera picture (BAR-6, BAR-7).
public struct ScannerState: Equatable, Sendable {
    /// Whether the camera has a torch. The torch button shows only then.
    public var hasTorch: Bool
    public var torchIsOn: Bool
    /// Where the person last tapped to focus, while the square shows there.
    public var focus: FocusMark?

    public init(hasTorch: Bool = false, torchIsOn: Bool = false, focus: FocusMark? = nil) {
        self.hasTorch = hasTorch
        self.torchIsOn = torchIsOn
        self.focus = focus
    }
}

/// A tap to focus, at a point in the scanner's own coordinates. Each tap gets a
/// new `id`, so tapping the same place again shows the square afresh.
public struct FocusMark: Equatable, Sendable {
    /// How long the square stays after a tap.
    public static let duration: Duration = .seconds(1)

    public var point: CGPoint
    public var id: Int

    public init(point: CGPoint, id: Int) {
        self.point = point
        self.id = id
    }
}
