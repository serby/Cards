import AVFoundation
import CardsCore
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
        VStack {
            if let barcodeImage = generateBarcode(from: barcodeString, type: barcodeType) {
                Image(uiImage: barcodeImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else {
                Text("Failed to generate barcode")
                    .foregroundColor(.red)
            }
        }
        .background(Color.white)
        .accessibilityIdentifier("barcodeView")
        .accessibilityHint("This is a \(barcodeType.rawValue) barcode with code \(barcodeString)")
    }

    public func generateBarcode(from code: String, type: BarcodeType) -> UIImage? {
        guard let metadataType = BarcodeMapper.mapBarcodeTypeToMetadataObjectType(type) else {
            return nil
        }
        let pixelWidth = pointsWidth * displayScale
        let pixelHeight = (pointsWidth / 3) * displayScale
        let barCodeSize = CGSize(width: pixelWidth, height: pixelHeight)
        return RSUnifiedCodeGenerator.shared.generateCode(
            code,
            machineReadableCodeObjectType: metadataType.rawValue,
            targetSize: barCodeSize
        )
    }
}
