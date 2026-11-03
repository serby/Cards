import SwiftUI

public extension ScreenBrightness {
    /// Keeps a value in memory without touching the device, so stories can show
    /// the brightness a view asked for without blinding the operator.
    static func simulated(_ box: BrightnessBox) -> ScreenBrightness {
        ScreenBrightness(
            read: { box.level },
            write: { box.level = max(0, min(1, $0)) }
        )
    }
}

/// Observable holder for `ScreenBrightness.simulated`.
@MainActor
@Observable
public final class BrightnessBox {
    public var level: CGFloat

    public init(level: CGFloat = 0.5) {
        self.level = level
    }
}

public extension AccessibilityAnnouncer {
    /// Swallows announcements, so stories and previews never speak.
    static let silent = Self { _ in }
}
