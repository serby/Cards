import AVFoundation
import RSBarcodes_Swift
import SwiftUI

public let pointsWidth: CGFloat = 400

public struct BarcodeView: View {
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
                } else {
                    Text(
                        "Failed to generate barcode",
                        comment: "Shown instead of the barcode when the card's code can't be drawn in the chosen barcode format."
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.white)
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
    }

    public func generateBarcode(from code: String, type: BarcodeType) -> UIImage? {
        let height = type.isSquare ? pointsWidth : pointsWidth / 3
        let size = CGSize(width: pointsWidth * displayScale, height: height * displayScale)
        return BarcodeImage.make(code, type: type, size: size)
    }
}
