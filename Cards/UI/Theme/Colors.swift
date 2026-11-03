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
    static let secondaryText = Color(light: Color(rgb: secondaryTextLightRGB), dark: Color(rgb: secondaryTextDarkRGB))
    /// Brand pink. Light mode uses a deeper shade so text and controls meet
    /// WCAG AA on white and on the light grey of bars, fields and grouped
    /// backgrounds; `CardColorTests` checks both modes.
    static let accentLightRGB: UInt32 = 0xD0185B
    static let accentDarkRGB: UInt32 = 0xFF6699
    static let accent = Color(light: Color(rgb: accentLightRGB), dark: Color(rgb: accentDarkRGB))
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
}
