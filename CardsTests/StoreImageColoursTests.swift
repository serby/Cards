@testable import Cards
import Foundation
import SwiftUI
import Testing

/// The colours the App Store image templates draw with
/// (screenshots/templates/card-colours.json): each palette colour's gradient
/// and ink, the white panel's inks and the brand pink, taken from the app so the
/// images and the app never disagree. The file is checked in; this fails when it
/// no longer matches the palette, and CARDS_WRITE_CARD_COLOURS=1 writes it afresh.
struct StoreImageColoursTests {
    private static let file = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "screenshots/templates/card-colours.json")

    private static func hex(_ rgb: UInt32) -> String {
        String(format: "\"#%06X\"", rgb & 0xFFFFFF)
    }

    /// The file's text: two-space JSON, colours in the palette's order.
    static func expected() -> String {
        let cards = CardColor.allCases.compactMap { color -> String? in
            guard let stops = color.gradientStops, let background = color.background else { return nil }
            let ink = CardInk.best(on: background).rgb
            return "    \"\(color.rawValue)\": { \"top\": \(hex(stops.top)), \"bottom\": \(hex(stops.bottom)), \"ink\": \(hex(ink)) }"
        }
        return """
            {
              "accent": \(hex(Color.accentLightRGB)),
              "panel": { "fill": "#FFFFFF", "ink": \(hex(CardInk.dark.rgb)), "secondaryInkOpacity": \(CardPanel.secondaryInkOpacity) },
              "cards": {
            \(cards.joined(separator: ",\n"))
              }
            }

            """
    }

    @Test func theTemplatesHaveTheAppsColours() throws {
        let json = Self.expected()
        if ProcessInfo.processInfo.environment["CARDS_WRITE_CARD_COLOURS"] == "1" {
            try json.write(to: Self.file, atomically: true, encoding: .utf8)
        }
        let written = try String(contentsOf: Self.file, encoding: .utf8)
        #expect(written == json, "Run the unit tests with TEST_RUNNER_CARDS_WRITE_CARD_COLOURS=1 to update \(Self.file.lastPathComponent)")
    }
}
