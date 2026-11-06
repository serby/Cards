@testable import Cards
import Foundation
import SwiftUI
import Testing

/// Guards the promise that a card stays readable whatever colour it is, palette
/// or custom, and that the app's own text can always be read. Thresholds are
/// WCAG 2 AA for normal-size text and never go down. The tests that take a
/// `ColorScheme` resolve the colours the views actually draw, as SwiftUI does,
/// so system colours are covered as well as the palette.
struct CardColorTests {
    private static let palette = CardColor.allCases.filter { $0 != .standard }
    private static let minimumContrast = 4.5
    private static let schemes: [ColorScheme] = [.light, .dark]

    /// A spread of custom colours: every channel at 0x00, 0x33 … 0xFF.
    private static let customColours: [CardColor] = {
        let steps: [UInt32] = [0x00, 0x33, 0x66, 0x99, 0xCC, 0xFF]
        return steps.flatMap { red in
            steps.flatMap { green in steps.map { blue in .custom(red << 16 | green << 8 | blue) } }
        }
    }()

    @Test func standardFollowsTheSystemAppearance() {
        #expect(CardColor.standard.background == nil)
        #expect(CardColor.standard.gradientStops == nil)
    }

    /// Card text sits on white panels in dark ink, whatever the card colour.
    @Test func panelTextIsReadable() {
        #expect(Contrast.ratio(CardInk.dark.rgb, 0xFFFFFF) >= Self.minimumContrast)
        let secondary = Contrast.blend(CardInk.dark.rgb, over: 0xFFFFFF, opacity: CardPanel.secondaryInkOpacity)
        #expect(Contrast.ratio(secondary, 0xFFFFFF) >= Self.minimumContrast)
    }

    /// The picker's tick is drawn straight on the swatch in its best ink.
    @Test(arguments: palette)
    func paletteInkIsReadable(_ color: CardColor) throws {
        let background = try #require(color.background)
        #expect(Contrast.ratio(CardInk.best(on: background).rgb, background) >= Self.minimumContrast)
    }

    @Test func bestInkIsTheOneThatStandsOut() {
        #expect(CardInk.best(on: 0xFFFFFF) == .dark)
        #expect(CardInk.best(on: 0xFFFF00) == .dark)
        #expect(CardInk.best(on: 0x000000) == .light)
        #expect(CardInk.best(on: 0x1458B0) == .light)
    }

    /// A list row puts the card name straight on the colour's gradient, so its
    /// ink must meet AA at both ends, for any colour at all. Mid greys are where
    /// neither ink is enough until the colour is moved.
    @Test(arguments: palette + customColours + [0x767676, 0x777777, 0x808080, 0x8A8A8A, 0x6E8B3D].map(CardColor.custom))
    func textOnTheColourIsReadable(_ color: CardColor) throws {
        let background = try #require(color.background)
        let stops = try #require(color.gradientStops)
        let ink = CardInk.best(on: background).rgb
        #expect(Contrast.ratio(ink, stops.top) >= Self.minimumContrast)
        #expect(Contrast.ratio(ink, stops.bottom) >= Self.minimumContrast)
    }

    /// Only colours that need it are moved: the palette shows exactly as designed.
    @Test(arguments: palette)
    func paletteColoursAreNotMoved(_ color: CardColor) {
        #expect(color.readableBackground == color.background)
    }

    @Test func midGreyIsMovedOnlyAsFarAsItTakes() throws {
        let grey = CardColor.custom(0x808080)
        let moved = try #require(grey.readableBackground)
        #expect(moved != 0x808080)
        let ink = CardInk.best(on: 0x808080).rgb
        #expect(Contrast.ratio(ink, moved) >= Self.minimumContrast)
        #expect(Contrast.ratio(ink, moved) < Self.minimumContrast + 0.5)
    }

    /// Supporting text (the version, section headings, a location's radius, the
    /// location picker's messages) on every surface it is drawn on.
    @Test func secondaryTextIsReadableOnEverySurface() {
        let surfaces: [(name: String, color: Color)] = [
            ("system background", .primaryBackground),
            ("secondary background", .secondaryBackground),
            ("grouped background", Color(UIColor.systemGroupedBackground)),
            ("grouped cell", Color(UIColor.secondarySystemGroupedBackground)),
            // The location picker's fields, whose prompts are secondary text.
            ("picker field", Color(UIColor.tertiarySystemFill))
        ]
        for scheme in Self.schemes {
            for surface in surfaces {
                let background = Resolved.rgb(surface.color, over: Resolved.rgb(.primaryBackground, in: scheme), in: scheme)
                let text = Resolved.rgb(.secondaryText, over: background, in: scheme)
                #expect(Contrast.ratio(text, background) >= Self.minimumContrast, "\(surface.name), \(scheme)")
            }
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

    /// Delete All Cards in Settings is drawn in the destructive red on a list
    /// cell.
    @Test func destructiveIsReadableOnCells() {
        for scheme in Self.schemes {
            for surface in [Color.primaryBackground, Color(UIColor.secondarySystemGroupedBackground)] {
                let background = Resolved.rgb(surface, in: scheme)
                let red = Resolved.rgb(.destructive, over: background, in: scheme)
                #expect(Contrast.ratio(red, background) >= Self.minimumContrast, "\(scheme)")
            }
        }
    }

    /// With Increase Contrast the app's own colours get stronger, never weaker,
    /// on the surfaces they are drawn on.
    @Test func increasedContrastIsAtLeastAsReadable() {
        let light: [UInt32] = [0xFFFFFF, 0xF2F2F7]
        let dark: [UInt32] = [0x000000, 0x1C1C1E]
        struct Pair {
            let name: String
            let standard: UInt32
            let increased: UInt32
            let surfaces: [UInt32]
        }
        let pairs = [
            Pair(
                name: "secondary text, light",
                standard: Color.secondaryTextLightRGB,
                increased: Color.secondaryTextIncreasedLightRGB,
                surfaces: light
            ),
            Pair(name: "secondary text, dark", standard: Color.secondaryTextDarkRGB, increased: Color.secondaryTextIncreasedDarkRGB, surfaces: dark),
            Pair(name: "accent, light", standard: Color.accentLightRGB, increased: Color.accentIncreasedLightRGB, surfaces: light),
            Pair(name: "accent, dark", standard: Color.accentDarkRGB, increased: Color.accentIncreasedDarkRGB, surfaces: dark),
            Pair(name: "destructive, light", standard: Color.destructiveLightRGB, increased: Color.destructiveIncreasedLightRGB, surfaces: light),
            Pair(name: "destructive, dark", standard: Color.destructiveDarkRGB, increased: Color.destructiveIncreasedDarkRGB, surfaces: dark)
        ]
        for pair in pairs {
            for surface in pair.surfaces {
                #expect(Contrast.ratio(pair.increased, surface) >= Contrast.ratio(pair.standard, surface), "\(pair.name)")
                #expect(Contrast.ratio(pair.increased, surface) >= Self.minimumContrast, "\(pair.name)")
            }
        }
    }

    @Test func storedValuesRoundTrip() {
        for color in CardColor.allCases + [.custom(0x123ABC), .custom(0x000000), .custom(0xFFFFFF)] {
            #expect(CardColor.stored(color.rawValue) == color)
        }
    }

    /// Cards saved before the palette grew must keep their colour.
    @Test func earlierPaletteNamesStillMatch() {
        let earlier = ["standard", "red", "orange", "yellow", "green", "teal", "blue", "indigo", "purple", "pink", "brown", "graphite"]
        for name in earlier {
            #expect(CardColor.stored(name).rawValue == name)
        }
    }

    @Test func customColoursAreStoredAsHex() {
        #expect(CardColor.custom(0x3399CC).rawValue == "#3399CC")
        #expect(CardColor.stored("#3399cc") == .custom(0x3399CC))
        #expect(CardColor.custom(0x3399CC).background == 0x3399CC)
    }

    @Test func unknownStoredValueFallsBackToStandard() {
        for value in ["chartreuse", "", "#12345", "#1234567", "3399CC", "#33 9CC", "#+12345", "#GGGGGG"] {
            #expect(CardColor.stored(value) == .standard, "\(value)")
        }
        #expect(CardColor.stored(nil) == .standard)
    }

    @Test func colourEncodesAsItsStoredString() throws {
        let data = try JSONEncoder().encode([CardColor.blue, .custom(0x3399CC)])
        #expect(String(data: data, encoding: .utf8) == ##"["blue","#3399CC"]"##)
        #expect(try JSONDecoder().decode([CardColor].self, from: data) == [.blue, .custom(0x3399CC)])
        #expect(try JSONDecoder().decode([CardColor].self, from: Data(#"["chartreuse"]"#.utf8)) == [.standard])
    }

    @Test func pickedColourBecomesCustom() {
        #expect(CardColor.custom(from: Color(.sRGB, red: 1, green: 0, blue: 0)) == .custom(0xFF0000))
        #expect(CardColor.custom(from: Color(.sRGB, red: 0.2, green: 0.6, blue: 0.8)) == .custom(0x3399CC))
    }

    @Test func displayNamesAreUnique() {
        let names = CardColor.allCases.map(\.displayName.key)
        #expect(Set(names).count == names.count)
    }

    @Test(arguments: CardColor.allCases + [.custom(0x3399CC)])
    func everyColourHasADisplayName(_ color: CardColor) {
        #expect(!color.displayName.key.isEmpty)
        #expect(!String(localized: color.displayName).isEmpty)
    }

    /// The picker's grid is six wide, and the custom well takes the last cell.
    @Test func paletteFillsWholeRowsWithTheCustomWell() {
        #expect((CardColor.allCases.count + 1) % 6 == 0)
    }
}

/// Corners nest: a shape inset into another takes its radius minus the inset.
struct CardGeometryTests {
    @Test func radiiNest() {
        #expect(CardGeometry.panelCornerRadius == CardGeometry.cornerRadius - CardGeometry.inset)
        #expect(CardGeometry.barcodeCornerRadius == CardGeometry.panelCornerRadius - CardGeometry.barcodeFrame)
        #expect(CardGeometry.barcodeCornerRadius > 0)
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
