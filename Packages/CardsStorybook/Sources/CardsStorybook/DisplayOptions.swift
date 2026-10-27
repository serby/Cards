import SwiftUI

public enum ColourSchemeChoice: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    var preferred: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

/// Display conditions applied to whichever story is on screen, so a layout can
/// be checked in dark mode, at accessibility text sizes, and right-to-left
/// without leaving the storybook.
@MainActor
@Observable
public final class DisplayOptions {
    public var colourScheme: ColourSchemeChoice = .system
    public var typeSize: DynamicTypeSize = .large
    public var rightToLeft = false

    public init() {}

    static let typeSizes: [DynamicTypeSize] = [
        .xSmall,
        .large,
        .xxxLarge,
        .accessibility3,
        .accessibility5
    ]

    var layoutDirection: LayoutDirection {
        rightToLeft ? .rightToLeft : .leftToRight
    }
}

extension DynamicTypeSize {
    var label: String {
        switch self {
        case .xSmall:
            return "xSmall"
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        case .xLarge:
            return "xLarge"
        case .xxLarge:
            return "xxLarge"
        case .xxxLarge:
            return "xxxLarge"
        case .accessibility1:
            return "A11y 1"
        case .accessibility2:
            return "A11y 2"
        case .accessibility3:
            return "A11y 3"
        case .accessibility4:
            return "A11y 4"
        case .accessibility5:
            return "A11y 5"
        @unknown default:
            return "Unknown"
        }
    }
}
