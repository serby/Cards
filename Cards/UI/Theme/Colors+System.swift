import SwiftUI

/// The colours the app and the widget draw with: iOS's system colours for
/// backgrounds and text, and the app's own colours (`Colors.swift`) for each
/// appearance. watchOS has none of iOS's system colours, so the Apple Watch app
/// does not share this file.
public extension Color {
    static let primaryBackground = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    /// A row of a form or list: white in light mode, so it stands out from the grey behind it.
    static let rowBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let primaryText = Color(UIColor.label)
    static let secondaryText = Color(
        lightRGB: secondaryTextLightRGB,
        darkRGB: secondaryTextDarkRGB,
        increasedLightRGB: secondaryTextIncreasedLightRGB,
        increasedDarkRGB: secondaryTextIncreasedDarkRGB
    )
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
