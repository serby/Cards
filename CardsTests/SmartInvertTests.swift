@testable import Cards
import SwiftUI
import Testing

/// Smart Invert must leave barcodes and card colours as they are: many
/// scanners cannot read an inverted barcode, and a red card would show cyan.
/// SwiftUI draws into a single layer and offers no way to read the flag back,
/// and a test cannot turn Smart Invert on, so these check that the views apply
/// `keepsColoursWhenInverted()` where it matters.
@MainActor
struct SmartInvertTests {
    @Test(arguments: [("5012345678900", BarcodeType.ean13), ("https://serby.net", .qrCode), ("nope", .ean13)])
    func barcodesKeepTheirColours(_ code: String, _ type: BarcodeType) {
        let barcode = BarcodeView(barcodeString: code, barcodeType: type)
        #expect(ViewTree.count(of: KeepsColoursWhenInverted.self, in: barcode.body) == 1)
    }

    @Test(arguments: CardColor.allCases)
    func cardFacesKeepTheirColours(_ color: CardColor) {
        let card = CardDetail(
            id: "1",
            name: "Tesco Clubcard",
            code: "5012345678900",
            barcodeType: .ean13,
            timestamp: .now,
            color: color
        )
        let detail = CardDetailView(card: card, brightnessBoost: .constant(false))
        #expect(ViewTree.count(of: KeepsColoursWhenInverted.self, in: detail.body) == 1)
    }

    @Test(arguments: CardColor.allCases)
    func swatchesKeepTheirColours(_ color: CardColor) {
        let picker = CardColorPicker(selection: .constant(.blue))
        #expect(ViewTree.count(of: KeepsColoursWhenInverted.self, in: picker.swatch(for: color)) == 1)
    }
}

/// Walks a view value's stored properties, which is as far as reflection can
/// see: it does not run closures or other views' bodies.
private enum ViewTree {
    static func count<Target>(of target: Target.Type, in value: Any, depth: Int = 0) -> Int {
        if value is Target { return 1 }
        guard depth < 100 else { return 0 }
        return Mirror(reflecting: value).children.reduce(0) { total, child in
            total + count(of: target, in: child.value, depth: depth + 1)
        }
    }
}
