import AVFoundation
import RSBarcodes_Swift
import SwiftUI

public let pointsWidth: CGFloat = 400

public struct BarcodeView: View {
    /// The plate the bars sit on. Always white, whatever the appearance, as
    /// scanners expect dark bars on a light ground.
    static let plate = Color.white
    /// Text drawn on the plate, the same in light and dark mode because the
    /// plate is.
    static let plateInk = Color(rgb: CardInk.dark.rgb)

    public let barcodeString: String
    public let barcodeType: BarcodeType
    @Environment(\.displayScale) private var displayScale

    public init(barcodeString: String, barcodeType: BarcodeType) {
        self.barcodeString = barcodeString
        self.barcodeType = barcodeType
    }

    public var body: some View {
        Group {
            Group {
                if let barcodeImage = generateBarcode(from: barcodeString, type: barcodeType) {
                    Image(uiImage: barcodeImage)
                        .resizable()
                        .scaledToFit()
                        // A mirrored barcode will not scan, so it stays as drawn
                        // in right-to-left languages too.
                        .flipsForRightToLeftLayoutDirection(false)
                } else {
                    Text(
                        "Failed to generate barcode",
                        comment: "Shown instead of the barcode when the card's code can't be drawn in the chosen barcode format."
                    )
                    .foregroundStyle(Self.plateInk)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Self.plate)
        }
        .padding(6)
        .background(.gray.opacity(0.5), in: .rect(cornerRadius: 12))
        .accessibilityIdentifier("barcodeView")
        .accessibilityHint(
            Text(
                "This is a \(barcodeType.displayName) barcode with code \(barcodeString)",
                comment: "VoiceOver hint for a barcode. The first argument is its format, such as EAN-13; the second is the card's code."
            )
        )
        .keepsColoursWhenInverted()
    }

    public func generateBarcode(from code: String, type: BarcodeType) -> UIImage? {
        let height = type.isSquare ? pointsWidth : pointsWidth / 3
        let size = CGSize(width: pointsWidth * displayScale, height: height * displayScale)
        return BarcodeImage.make(code, type: type, size: size)
    }
}
