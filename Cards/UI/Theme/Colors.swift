import SwiftUI

public extension Color {
    static let primaryBackground = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    /// A row of a form or list: white in light mode, so it stands out from the grey behind it.
    static let rowBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let primaryText = Color(UIColor.label)
    static let secondaryText = Color(UIColor.secondaryLabel)
    static let tertiaryText = Color(UIColor.tertiaryLabel)
    /// Brand pink. Light mode uses a deeper shade so text and controls meet
    /// WCAG AA on white; `CardColorTests` checks both.
    static let accentLightRGB: UInt32 = 0xD81B60
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
