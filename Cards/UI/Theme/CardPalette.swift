import SwiftUI
import UIKit

/// Whether marks drawn straight on a card colour are light or dark.
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

    public var color: Color { Color(rgb: rgb) }

    /// Whichever ink stands out more against `background`.
    public static func best(on background: UInt32) -> Self {
        let lightContrast = WCAG.contrast(Self.light.rgb, background)
        let darkContrast = WCAG.contrast(Self.dark.rgb, background)
        return lightContrast >= darkContrast ? .light : .dark
    }
}

/// Text never sits straight on a card colour, which can be any colour at all.
/// It sits on these white panels in dark ink (see docs/STYLE.md).
public enum CardPanel {
    public static let fill = Color.white
    public static let ink = CardInk.dark.color
    /// Supporting text: a place, a date.
    public static let secondaryInkOpacity = 0.7
    public static let secondaryInk = ink.opacity(secondaryInkOpacity)
}

public extension CardColor {
    /// Opacity of the card colour washed behind its list row. Dark mode needs a
    /// stronger wash to read as the same hint against a black background.
    static let hintOpacityLight = 0.22
    static let hintOpacityDark = 0.36

    /// sRGB as 0xRRGGBB; `nil` for `.standard`, which follows the system appearance.
    var background: UInt32? {
        switch self {
        case .standard:
            nil
        case .red:
            0xB3261E
        case .coral:
            0xE5735A
        case .orange:
            0xF28C28
        case .yellow:
            0xF9C74F
        case .lime:
            0x9CCC65
        case .green:
            0x24692B
        case .olive:
            0x556B2F
        case .mint:
            0x4DB6AC
        case .teal:
            0x00695C
        case .sky:
            0x4FC3F7
        case .blue:
            0x1458B0
        case .indigo:
            0x3F51B5
        case .navy:
            0x1A237E
        case .lavender:
            0xB39DDB
        case .purple:
            0x7B1FA2
        case .pink:
            0xAD1457
        case .rose:
            0xF48FB1
        case .maroon:
            0x7F1D1D
        case .brown:
            0x795548
        case .sand:
            0xD7CCC8
        case .graphite:
            0x455A64
        case .black:
            0x121212
        case .custom(let rgb):
            rgb & 0xFFFFFF
        }
    }

    var displayName: String {
        switch self {
        case .standard:
            "Default"
        case .red:
            "Red"
        case .coral:
            "Coral"
        case .orange:
            "Orange"
        case .yellow:
            "Yellow"
        case .lime:
            "Lime"
        case .green:
            "Green"
        case .olive:
            "Olive"
        case .mint:
            "Mint"
        case .teal:
            "Teal"
        case .sky:
            "Sky"
        case .blue:
            "Blue"
        case .indigo:
            "Indigo"
        case .navy:
            "Navy"
        case .lavender:
            "Lavender"
        case .purple:
            "Purple"
        case .pink:
            "Pink"
        case .rose:
            "Rose"
        case .maroon:
            "Maroon"
        case .brown:
            "Brown"
        case .sand:
            "Sand"
        case .graphite:
            "Graphite"
        case .black:
            "Black"
        case .custom:
            "Custom"
        }
    }

    /// The flat colour, or `nil` for `.standard`.
    var backgroundColor: Color? {
        background.map(Color.init(rgb:))
    }

    /// The card face, the widget and the picker's swatches: the colour as a soft
    /// gradient. `.standard` is a translucent grey over the system background.
    var cardFill: AnyShapeStyle {
        AnyShapeStyle((backgroundColor ?? Color.gray.opacity(0.25)).gradient)
    }

    /// The Home Screen widget's background: the colour, or the system background
    /// for `.standard`, as a gradient.
    var widgetFill: AnyShapeStyle {
        AnyShapeStyle((backgroundColor ?? .primaryBackground).gradient)
    }

    /// Marks drawn straight on the colour, such as the picker's tick.
    var ink: Color {
        background.map { CardInk.best(on: $0).color } ?? .primary
    }

    /// A list row: a faint wash of the card colour, or the grouped background
    /// for `.standard` so every row reads as the same shape. `CardColorTests`
    /// checks the system label stays readable over the wash of any colour.
    var rowFill: Color {
        backgroundColor.map { color in
            Color(light: color.opacity(Self.hintOpacityLight), dark: color.opacity(Self.hintOpacityDark))
        } ?? .secondaryBackground
    }

    /// A custom card colour from a colour the user picked, in sRGB.
    static func custom(from color: Color) -> Self {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let byte = { (value: CGFloat) in UInt32((min(max(value, 0), 1) * 255).rounded()) }
        return .custom(byte(red) << 16 | byte(green) << 8 | byte(blue))
    }
}

/// WCAG 2 relative luminance and contrast, for opaque 0xRRGGBB sRGB colours.
enum WCAG {
    static func contrast(_ first: UInt32, _ second: UInt32) -> Double {
        let (one, two) = (luminance(first), luminance(second))
        return (max(one, two) + 0.05) / (min(one, two) + 0.05)
    }

    static func luminance(_ rgb: UInt32) -> Double {
        let linear = [(rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF].map { channel -> Double in
            let value = Double(channel) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
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
