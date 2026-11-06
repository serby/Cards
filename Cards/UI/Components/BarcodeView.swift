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
                    // Dark ink: the white stays white in dark mode, where the default would vanish.
                    Text("Failed to generate barcode")
                        .foregroundStyle(CardPanel.ink)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.white, in: .rect(cornerRadius: CardGeometry.barcodeCornerRadius))
        }
        .padding(CardGeometry.barcodeFrame)
        .background(.gray.opacity(0.5), in: .rect(cornerRadius: CardGeometry.panelCornerRadius))
        .accessibilityIdentifier("barcodeView")
        .accessibilityHint("This is a \(barcodeType.rawValue) barcode with code \(barcodeString)")
    }

    public func generateBarcode(from code: String, type: BarcodeType) -> UIImage? {
        let height = type.isSquare ? pointsWidth : pointsWidth / 3
        let size = CGSize(width: pointsWidth * displayScale, height: height * displayScale)
        return BarcodeImage.make(code, type: type, size: size)
    }
}

#if DEBUG
#Preview {
    BarcodeView(barcodeString: "123456", barcodeType: .code128)
    BarcodeView(barcodeString: "", barcodeType: .ean13)
}
#endif
