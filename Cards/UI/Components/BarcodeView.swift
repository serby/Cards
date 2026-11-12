import AVFoundation
import RSBarcodes_Swift
import SwiftUI

public struct BarcodeView: View {
    /// The plate the bars sit on. Always white, whatever the appearance, as
    /// scanners expect dark bars on a light ground.
    static let plate = Color.white
    /// Text drawn on the plate, the same in light and dark mode because the
    /// plate is.
    static let plateInk = CardPanel.ink

    public let barcodeString: String
    public let barcodeType: BarcodeType
    @Environment(\.displayScale) private var displayScale

    public init(barcodeString: String, barcodeType: BarcodeType) {
        self.barcodeString = barcodeString
        self.barcodeType = barcodeType
    }

    public var body: some View {
        let barcodeImage = generateBarcode(from: barcodeString, type: barcodeType)
        Group {
            Group {
                if let barcodeImage {
                    Image(uiImage: barcodeImage)
                        .resizable()
                        .scaledToFit()
                        // A mirrored barcode will not scan, so it stays as drawn
                        // in right-to-left languages too.
                        .flipsForRightToLeftLayoutDirection(false)
                } else {
                    // Centred on the plate when it wraps, as it does in longer
                    // languages and at large text sizes. Dark ink: the white
                    // stays white in dark mode, where the default would vanish.
                    failureText
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Self.plateInk)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(CardGeometry.barcodePlatePadding)
            .background(Self.plate, in: .rect(cornerRadius: CardGeometry.barcodeCornerRadius))
        }
        .padding(CardGeometry.barcodeFrame)
        .background(.gray.opacity(0.5), in: .rect(cornerRadius: CardGeometry.panelCornerRadius))
        // One element that says what is shown: the barcode and its format, or
        // the failure, never "barcode" over a message. The code itself is read
        // out, spelled, by the line under the barcode.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            barcodeImage == nil
                ? failureText
                : Text("Barcode", comment: "VoiceOver label for the barcode on a card's screen. Its format, such as EAN-13, is read after it.")
        )
        .accessibilityValue(Text(barcodeType.displayName))
        .accessibilityAddTraits(barcodeImage == nil ? [] : .isImage)
        .accessibilityIdentifier("barcodeView")
        .keepsColoursWhenInverted()
    }

    private var failureText: Text {
        Text(
            "Failed to generate barcode",
            comment: "Shown instead of the barcode when the card's code can't be drawn in the chosen barcode format."
        )
    }

    public func generateBarcode(from code: String, type: BarcodeType) -> UIImage? {
        let width = CardGeometry.maximumBarcodeWidth
        let height = type.isSquare ? width : width / 3
        let size = CGSize(width: width * displayScale, height: height * displayScale)
        return BarcodeImage.make(code, type: type, size: size)
    }
}

#if DEBUG
#Preview {
    BarcodeView(barcodeString: "123456", barcodeType: .code128)
    BarcodeView(barcodeString: "", barcodeType: .ean13)
}
#endif
