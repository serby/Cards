import RSBarcodes_Swift
import UIKit

/// Renders a code as an image. Shared by `BarcodeView` and the Lock Screen
/// arrival notifications so both draw exactly the same barcode.
public enum BarcodeImage {
    /// The bare code at `size` pixels, or `nil` if the code is not valid for `type`.
    public static func make(_ code: String, type: BarcodeType, size: CGSize) -> UIImage? {
        guard let metadataType = BarcodeMapper.mapBarcodeTypeToMetadataObjectType(type) else {
            return nil
        }
        return RSUnifiedCodeGenerator.shared.generateCode(
            code,
            machineReadableCodeObjectType: metadataType.rawValue,
            targetSize: size
        )
    }

    /// PNG of the code on a white card with a quiet zone, ready for a scanner.
    public static func pngOnWhite(_ code: String, type: BarcodeType) -> Data? {
        let codeSize = type.isSquare ? CGSize(width: 600, height: 600) : CGSize(width: 1_200, height: 400)
        guard let image = make(code, type: type, size: codeSize) else { return nil }
        let margin: CGFloat = 60
        let canvas = CGSize(width: codeSize.width + margin * 2, height: codeSize.height + margin * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: canvas, format: format).pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))
            image.draw(in: CGRect(origin: CGPoint(x: margin, y: margin), size: codeSize))
        }
    }
}
