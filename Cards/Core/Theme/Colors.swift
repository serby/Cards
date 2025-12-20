import SwiftUI

extension Color {
    // MARK: - Primary Colors (Adaptive)
    static let primaryBackground = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    
    // MARK: - Text Colors (Adaptive)
    static let primaryText = Color(UIColor.label)
    static let secondaryText = Color(UIColor.secondaryLabel)
    static let tertiaryText = Color(UIColor.tertiaryLabel)
    
    // MARK: - Pink Accent (Brand color - same in both modes)
    static let accent = Color(red: 1.0, green: 0.4, blue: 0.6)
    static let accentLight = Color(light: Color(red: 1.0, green: 0.85, blue: 0.9),
                                   dark: Color(red: 0.4, green: 0.15, blue: 0.25))
    
    // MARK: - Greys (Adaptive)
    static let border = Color(UIColor.separator)
    static let separator = Color(UIColor.separator)
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let shadow = Color.black.opacity(0.05)
    
    // MARK: - Helper for light/dark variants
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
