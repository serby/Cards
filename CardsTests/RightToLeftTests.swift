@testable import Cards
import SwiftUI
import Testing

/// Arabic lays the app out right to left. Barcodes and codes must not follow:
/// a mirrored barcode will not scan, and a reordered code is a different code.
@MainActor
struct RightToLeftTests {
    private func rendered(_ view: some View, _ direction: LayoutDirection) -> Data? {
        Snapshot.png(view.environment(\.layoutDirection, direction))
    }

    @Test(arguments: [
        (BarcodeType.ean13, "5012345678900"),
        (BarcodeType.code128, "ABC-1234"),
        (BarcodeType.qrCode, "https://serby.net")
    ])
    func barcodesNeverMirror(_ type: BarcodeType, _ code: String) {
        let barcode = BarcodeView(barcodeString: code, barcodeType: type)
            .frame(width: 320, height: type.isSquare ? 320 : 140)
        let leftToRight = rendered(barcode, .leftToRight)
        #expect(leftToRight != nil)
        #expect(rendered(barcode, .rightToLeft) == leftToRight)
    }

    @Test func codesReadLeftToRightInARightToLeftLayout() {
        let code = Text(verbatim: "123-ABC 45").readsLeftToRight()
        #expect(rendered(code, .rightToLeft) == rendered(code, .leftToRight))
    }

    /// The same code without the modifier is reordered, so the test above is
    /// checking something real.
    @Test func codesWithoutTheModifierAreReordered() {
        let code = Text(verbatim: "123-ABC 45")
        #expect(rendered(code, .rightToLeft) != rendered(code, .leftToRight))
    }
}
