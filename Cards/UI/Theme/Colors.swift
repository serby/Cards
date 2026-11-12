import SwiftUI

/// The app's own colours as sRGB 0xRRGGBB, one for each appearance and a
/// stronger one for each with Increase Contrast. Plain values, so the Apple
/// Watch app, which has none of iOS's system colours, shares them, and the
/// website reads them from this file (`scripts/lib/website.ts`). The SwiftUI
/// colours made from them are in `Colors+System.swift`.
public extension Color {
    /// Supporting text: values, captions, section headings. Opaque, and darker
    /// than the system's `secondaryLabel` (3.4:1 on white), so it meets WCAG AA
    /// on every surface the app draws it on; `CardColorTests` checks each one.
    static let secondaryTextLightRGB: UInt32 = 0x636366
    static let secondaryTextDarkRGB: UInt32 = 0xAEAEB2
    static let secondaryTextIncreasedLightRGB: UInt32 = 0x48484A
    static let secondaryTextIncreasedDarkRGB: UInt32 = 0xD1D1D6
    /// Brand pink. Light mode uses a deeper shade so text and controls meet
    /// WCAG AA on white and on the light grey of bars, fields and grouped
    /// backgrounds; `CardColorTests` checks both modes.
    static let accentLightRGB: UInt32 = 0xD0185B
    static let accentDarkRGB: UInt32 = 0xFF6699
    static let accentIncreasedLightRGB: UInt32 = 0xA8114A
    static let accentIncreasedDarkRGB: UInt32 = 0xFF8AB3
    /// Destructive actions. The system red is 3.6:1 on white, so this is the
    /// deeper red iOS itself uses at increased contrast.
    static let destructiveLightRGB: UInt32 = 0xD70015
    static let destructiveDarkRGB: UInt32 = 0xFF6961
    static let destructiveIncreasedLightRGB: UInt32 = 0xB00012
    static let destructiveIncreasedDarkRGB: UInt32 = 0xFF8C82
}
