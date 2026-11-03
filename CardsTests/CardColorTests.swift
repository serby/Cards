@testable import Cards
import Foundation
import SwiftUI
import Testing

/// Guards the promise that a card's text can always be read, whatever colour
/// the user picks. Thresholds are WCAG 2 AA for normal-size text.
struct CardColorTests {
    private static let colours = CardColor.allCases.filter { $0 != .standard }
    private static let minimumContrast = 4.5

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

    /// The list row draws the system label over a faint wash of the colour on
    /// the system background, in both appearances.
    @Test(arguments: colours)
    func listHintKeepsTheLabelReadable(_ color: CardColor) throws {
        let swatch = try #require(color.swatch)
        let lightRow = Contrast.blend(swatch.background, over: 0xFFFFFF, opacity: CardColor.hintOpacityLight)
        let darkRow = Contrast.blend(swatch.background, over: 0x000000, opacity: CardColor.hintOpacityDark)
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
