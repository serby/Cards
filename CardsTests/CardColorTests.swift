@testable import Cards
import Foundation
import SwiftUI
import Testing

/// Guards the promise that the app's text can always be read, whatever colour
/// the user picks. Thresholds are WCAG 2 AA for normal-size text. The tests
/// that take a `ColorScheme` resolve the colours the views actually draw, as
/// SwiftUI does, so system colours are covered as well as the palette.
struct CardColorTests {
    private static let colours = CardColor.allCases.filter { $0 != .standard }
    private static let minimumContrast = 4.5
    private static let schemes: [ColorScheme] = [.light, .dark]

    @Test func standardFollowsTheSystemAppearance() {
        #expect(CardColor.standard.swatch == nil)
        #expect(CardColor.standard.rowFill == .secondaryBackground)
    }

    @Test(arguments: colours)
    func primaryTextIsReadable(_ color: CardColor) throws {
        let swatch = try #require(color.swatch)
        #expect(Contrast.ratio(swatch.ink.rgb, swatch.background) >= Self.minimumContrast)
    }

    @Test(arguments: colours)
    func secondaryTextIsReadable(_ color: CardColor) throws {
        let swatch = try #require(color.swatch)
        let text = Contrast.blend(swatch.ink.rgb, over: swatch.background, opacity: CardSwatch.secondaryInkOpacity)
        #expect(Contrast.ratio(text, swatch.background) >= Self.minimumContrast)
    }

    /// The card face as the detail screen draws it, `.standard` included: the
    /// name and code in the primary ink, the distance and date in the
    /// secondary ink.
    @Test(arguments: CardColor.allCases)
    func cardFaceTextIsReadable(_ color: CardColor) {
        for scheme in Self.schemes {
            let face = Resolved.rgb(color.cardFill, over: Resolved.rgb(.primaryBackground, in: scheme), in: scheme)
            let primary = Resolved.rgb(color.primaryInk, over: face, in: scheme)
            let secondary = Resolved.rgb(color.secondaryInk, over: face, in: scheme)
            #expect(Contrast.ratio(primary, face) >= Self.minimumContrast, "primary ink, \(scheme)")
            #expect(Contrast.ratio(secondary, face) >= Self.minimumContrast, "secondary ink, \(scheme)")
        }
    }

    /// The list row draws its name and distance over a faint wash of the
    /// colour on the system background, in both appearances.
    @Test(arguments: CardColor.allCases)
    func listRowTextIsReadable(_ color: CardColor) {
        for scheme in Self.schemes {
            let row = Resolved.rgb(color.rowFill, over: Resolved.rgb(.primaryBackground, in: scheme), in: scheme)
            let text = Resolved.rgb(color.rowInk, over: row, in: scheme)
            #expect(Contrast.ratio(text, row) >= Self.minimumContrast, "\(scheme)")
        }
    }

    /// Supporting text (the version, the Brightness Boost description, section
    /// headings, a location's radius, the location picker's messages) on every
    /// surface it is drawn on.
    @Test func secondaryTextIsReadableOnEverySurface() {
        let surfaces: [(name: String, color: Color)] = [
            ("system background", .primaryBackground),
            ("secondary background", .secondaryBackground),
            ("grouped background", Color(UIColor.systemGroupedBackground)),
            ("grouped cell", Color(UIColor.secondarySystemGroupedBackground)),
            ("standard card face", CardColor.standard.cardFill)
        ]
        for scheme in Self.schemes {
            for surface in surfaces {
                let background = Resolved.rgb(surface.color, over: Resolved.rgb(.primaryBackground, in: scheme), in: scheme)
                let text = Resolved.rgb(.secondaryText, over: background, in: scheme)
                #expect(Contrast.ratio(text, background) >= Self.minimumContrast, "\(surface.name), \(scheme)")
            }
        }
    }

    /// The barcode plate stays white in dark mode, so the text drawn on it when
    /// a code cannot be drawn must not follow the appearance.
    @Test @MainActor func textOnTheBarcodePlateIsReadable() {
        for scheme in Self.schemes {
            let plate = Resolved.rgb(BarcodeView.plate, in: scheme)
            let text = Resolved.rgb(BarcodeView.plateInk, over: plate, in: scheme)
            #expect(Contrast.ratio(text, plate) >= Self.minimumContrast, "\(scheme)")
        }
    }

    /// The accent colours buttons and links, so it needs AA against the
    /// system background and the light grey of bars, fields and grouped
    /// backgrounds, in both appearances.
    @Test func accentIsReadableOnTheBackground() {
        for scheme in Self.schemes {
            for surface in [Color.primaryBackground, .secondaryBackground] {
                let background = Resolved.rgb(surface, in: scheme)
                let accent = Resolved.rgb(.accent, over: background, in: scheme)
                #expect(Contrast.ratio(accent, background) >= Self.minimumContrast, "\(scheme)")
            }
        }
    }

    @Test func storedValuesRoundTrip() {
        for color in CardColor.allCases {
            #expect(CardColor.stored(color.rawValue) == color)
        }
    }

    @Test func unknownStoredValueFallsBackToStandard() {
        #expect(CardColor.stored("chartreuse") == .standard)
        #expect(CardColor.stored("") == .standard)
        #expect(CardColor.stored(nil) == .standard)
    }

    @Test func displayNamesAreUnique() {
        let names = CardColor.allCases.map(\.displayName.key)
        #expect(Set(names).count == names.count)
    }

    @Test(arguments: CardColor.allCases)
    func everyColourHasADisplayName(_ color: CardColor) {
        #expect(!color.displayName.key.isEmpty)
        #expect(!String(localized: color.displayName).isEmpty)
    }
}

/// A SwiftUI colour as it is drawn in light or dark mode, as opaque 0xRRGGBB.
private enum Resolved {
    /// `color` resolved in `scheme` and, if it is translucent, composited over
    /// `background`.
    static func rgb(_ color: Color, over background: UInt32 = 0x000000, in scheme: ColorScheme) -> UInt32 {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let resolved = color.resolve(in: environment)
        let channels = [resolved.red, resolved.green, resolved.blue].map { channel in
            UInt32((min(max(Double(channel), 0), 1) * 255).rounded())
        }
        let top = channels[0] << 16 | channels[1] << 8 | channels[2]
        return Contrast.blend(top, over: background, opacity: Double(resolved.opacity))
    }
}

/// WCAG 2 relative luminance and contrast for opaque 0xRRGGBB sRGB colours.
private enum Contrast {
    static func ratio(_ first: UInt32, _ second: UInt32) -> Double {
        let lighter = max(luminance(first), luminance(second))
        let darker = min(luminance(first), luminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// `top` composited at `opacity` over `bottom`, in gamma-encoded sRGB as the
    /// renderer does.
    static func blend(_ top: UInt32, over bottom: UInt32, opacity: Double) -> UInt32 {
        let mixed = zip(channels(top), channels(bottom)).map { topChannel, bottomChannel in
            UInt32((topChannel * opacity + bottomChannel * (1 - opacity)).rounded())
        }
        return mixed[0] << 16 | mixed[1] << 8 | mixed[2]
    }

    private static func channels(_ rgb: UInt32) -> [Double] {
        [Double((rgb >> 16) & 0xFF), Double((rgb >> 8) & 0xFF), Double(rgb & 0xFF)]
    }

    private static func luminance(_ rgb: UInt32) -> Double {
        let linear = channels(rgb).map { channel -> Double in
            let value = channel / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}
