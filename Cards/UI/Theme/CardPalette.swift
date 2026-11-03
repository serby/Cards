import SwiftUI

/// Whether text on a card colour is drawn light or dark.
public enum CardInk: Sendable {
    case light
    case dark

    /// sRGB as 0xRRGGBB.
    public var rgb: UInt32 {
        switch self {
        case .light:
            0xFFFFFF
        case .dark:
            0x1C1C1E
        }
    }
}

/// A fixed card background and the ink drawn on it. `CardColorTests` checks every
/// swatch meets WCAG AA (4.5:1) for both primary and secondary text, and that the
/// list-row hint keeps the system label readable in light and dark mode.
public struct CardSwatch: Hashable, Sendable {
    /// Opacity of secondary text (card name, date) relative to the ink.
    public static let secondaryInkOpacity = 0.85

    /// sRGB as 0xRRGGBB.
    public let background: UInt32
    public let ink: CardInk

    public var backgroundColor: Color { Color(rgb: background) }
    public var inkColor: Color { Color(rgb: ink.rgb) }
}

public extension CardColor {
    /// Opacity of the card colour washed behind its list row. Dark mode needs a
    /// stronger wash to read as the same hint against a black background.
    static let hintOpacityLight = 0.22
    static let hintOpacityDark = 0.36

    /// `nil` for `.standard`, which follows the system appearance instead.
    var swatch: CardSwatch? {
        switch self {
        case .standard:
            nil
        case .red:
            CardSwatch(background: 0xB3261E, ink: .light)
        case .orange:
            CardSwatch(background: 0xF28C28, ink: .dark)
        case .yellow:
            CardSwatch(background: 0xF9C74F, ink: .dark)
        case .green:
            CardSwatch(background: 0x24692B, ink: .light)
        case .teal:
            CardSwatch(background: 0x00695C, ink: .light)
        case .blue:
            CardSwatch(background: 0x1458B0, ink: .light)
        case .indigo:
            CardSwatch(background: 0x3F51B5, ink: .light)
        case .purple:
            CardSwatch(background: 0x7B1FA2, ink: .light)
        case .pink:
            CardSwatch(background: 0xAD1457, ink: .light)
        case .brown:
            CardSwatch(background: 0x795548, ink: .light)
        case .graphite:
            CardSwatch(background: 0x455A64, ink: .light)
        }
    }

    /// The card face.
    var cardFill: AnyShapeStyle {
        swatch.map { AnyShapeStyle($0.backgroundColor) } ?? AnyShapeStyle(Color.gray.opacity(0.25))
    }

    /// Text on the card face: the code.
    var primaryInk: AnyShapeStyle {
        swatch.map { AnyShapeStyle($0.inkColor) } ?? AnyShapeStyle(.primary)
    }

    /// Supporting text on the card face: the name and date.
    var secondaryInk: AnyShapeStyle {
        swatch.map { AnyShapeStyle($0.inkColor.opacity(CardSwatch.secondaryInkOpacity)) }
            ?? AnyShapeStyle(.secondary)
    }

    /// A list row: a faint wash of the card colour, or the grouped background
    /// for `.standard` so every row reads as the same shape.
    var rowFill: Color {
        swatch.map { swatch in
            Color(
                light: swatch.backgroundColor.opacity(Self.hintOpacityLight),
                dark: swatch.backgroundColor.opacity(Self.hintOpacityDark)
            )
        } ?? .secondaryBackground
    }
}

extension Color {
    /// An opaque sRGB colour from 0xRRGGBB.
    init(rgb: UInt32) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
