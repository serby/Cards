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
                    Text("Failed to generate barcode")
                    
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.white)
        }
        .padding(6)
        .background(.gray.opacity(0.5), in: .rect(cornerRadius: 12))
        .accessibilityIdentifier("barcodeView")
        .accessibilityHint("This is a \(barcodeType.rawValue) barcode with code \(barcodeString)")
    }

    public func generateBarcode(from code: String, type: BarcodeType) -> UIImage? {
        let height = type.isSquare ? pointsWidth : pointsWidth / 3
        let size = CGSize(width: pointsWidth * displayScale, height: height * displayScale)
        return BarcodeImage.make(code, type: type, size: size)
    }
}

#Preview {
    BarcodeView(barcodeString: "123456", barcodeType: .code128)
    BarcodeView(barcodeString: "", barcodeType: .ean13)
}
