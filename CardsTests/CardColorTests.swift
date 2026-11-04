@testable import Cards
import Foundation
import SwiftUI
import Testing

/// Guards the promise that a card stays readable whatever colour it is, palette
/// or custom. Thresholds are WCAG 2 AA for normal-size text and never go down.
struct CardColorTests {
    private static let palette = CardColor.allCases.filter { $0 != .standard }
    private static let minimumContrast = 4.5

    /// A spread of custom colours: every channel at 0x00, 0x33 … 0xFF.
    private static let customColours: [CardColor] = {
        let steps: [UInt32] = [0x00, 0x33, 0x66, 0x99, 0xCC, 0xFF]
        return steps.flatMap { red in
            steps.flatMap { green in steps.map { blue in .custom(red << 16 | green << 8 | blue) } }
        }
    }()

    @Test func standardFollowsTheSystemAppearance() {
        #expect(CardColor.standard.background == nil)
        #expect(CardColor.standard.rowFill == .secondaryBackground)
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

    /// The list row draws the system label over a faint wash of the colour on
    /// the system background, in both appearances.
    @Test(arguments: palette + customColours)
    func listHintKeepsTheLabelReadable(_ color: CardColor) throws {
        let background = try #require(color.background)
        let lightRow = Contrast.blend(background, over: 0xFFFFFF, opacity: CardColor.hintOpacityLight)
        let darkRow = Contrast.blend(background, over: 0x000000, opacity: CardColor.hintOpacityDark)
        #expect(Contrast.ratio(0x000000, lightRow) >= Self.minimumContrast)
        #expect(Contrast.ratio(0xFFFFFF, darkRow) >= Self.minimumContrast)
    }

    /// The accent colours buttons and links, so it needs AA against the
    /// system background in both appearances.
    @Test func accentIsReadableOnTheBackground() {
        #expect(Contrast.ratio(Color.accentLightRGB, 0xFFFFFF) >= Self.minimumContrast)
        #expect(Contrast.ratio(Color.accentDarkRGB, 0x000000) >= Self.minimumContrast)
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
        let names = CardColor.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
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
