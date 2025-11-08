import AVFoundation
import RSBarcodes_Swift
import SwiftUI

let pointsWidth: CGFloat = 400

struct BarcodeView: View {
    let barcodeString: String
    let barcodeType: BarcodeType
    
    var body: some View {
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
    
    func generateBarcode(from code: String, type: BarcodeType) -> UIImage? {
        guard let metadataType = BarcodeMapper.mapBarcodeTypeToMetadataObjectType(type) else {
            return nil
        }
        let pixelWidth = pointsWidth * UIScreen.main.scale
        let pixelHeight = (pointsWidth / 3) * UIScreen.main.scale
        let barCodeSize = CGSize(width: pixelWidth, height: pixelHeight)
        
        let barcodeImage = RSUnifiedCodeGenerator.shared.generateCode(
            code,
            machineReadableCodeObjectType: metadataType.rawValue,
            targetSize: barCodeSize
        )
        
        return barcodeImage
    }
}

#Preview {
    BarcodeView(barcodeString: "1620000965", barcodeType: .code128)
    Spacer()
    BarcodeView(barcodeString: "1620000965", barcodeType: .code39)
}
