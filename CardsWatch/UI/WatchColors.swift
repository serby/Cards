import SwiftUI

/// The colours the watch draws with. watchOS has none of iOS's system colours
/// (`Colors+System.swift`) and is always dark, so the names the shared palette
/// calls on (`CardPalette.swift`) take watchOS's own dark values here, and the
/// app's colours (`Colors.swift`) their dark ones.
extension Color {
    static let primaryBackground = Color.black
    /// A list row of a Default card, as grey as watchOS's own rows.
    static let secondaryBackground = Color(white: 0.14)
    static let primaryText = Color.white
    /// Supporting text, as the app writes it in dark mode.
    static let secondaryText = Color(rgb: secondaryTextDarkRGB)
    /// The brand pink, as the app shows it in dark mode.
    static let accent = Color(rgb: accentDarkRGB)
}
