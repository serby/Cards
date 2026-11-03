import SwiftUI

public extension Color {
    static let primaryBackground = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let primaryText = Color(UIColor.label)
    /// Supporting text: values, captions, section headings. Opaque, and darker
    /// than the system's `secondaryLabel` (3.4:1 on white), so it meets WCAG AA
    /// on every surface the app draws it on; `CardColorTests` checks each one.
    static let secondaryTextLightRGB: UInt32 = 0x636366
    static let secondaryTextDarkRGB: UInt32 = 0xAEAEB2
    static let secondaryTextIncreasedLightRGB: UInt32 = 0x48484A
    static let secondaryTextIncreasedDarkRGB: UInt32 = 0xD1D1D6
    static let secondaryText = Color(
        lightRGB: secondaryTextLightRGB,
        darkRGB: secondaryTextDarkRGB,
        increasedLightRGB: secondaryTextIncreasedLightRGB,
        increasedDarkRGB: secondaryTextIncreasedDarkRGB
    )
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
    static let destructive = Color(
        lightRGB: destructiveLightRGB,
        darkRGB: destructiveDarkRGB,
        increasedLightRGB: destructiveIncreasedLightRGB,
        increasedDarkRGB: destructiveIncreasedDarkRGB
    )
    static let accent = Color(
        lightRGB: accentLightRGB,
        darkRGB: accentDarkRGB,
        increasedLightRGB: accentIncreasedLightRGB,
        increasedDarkRGB: accentIncreasedDarkRGB
    )
    static let accentLight = Color(light: Color(red: 1.0, green: 0.85, blue: 0.9),
                                   dark: Color(red: 0.4, green: 0.15, blue: 0.25))
    static let border = Color(UIColor.separator)
    static let separator = Color(UIColor.separator)
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let shadow = Color.black.opacity(0.05)

    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }

    /// An opaque sRGB colour for each appearance, with a stronger one for each
    /// when Increase Contrast is on.
    init(lightRGB: UInt32, darkRGB: UInt32, increasedLightRGB: UInt32, increasedDarkRGB: UInt32) {
        self.init(UIColor { traitCollection in
            let increased = traitCollection.accessibilityContrast == .high
            let rgb = traitCollection.userInterfaceStyle == .dark
                ? (increased ? increasedDarkRGB : darkRGB)
                : (increased ? increasedLightRGB : lightRGB)
            return UIColor(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
