import RSBarcodes_Swift
import UIKit

/// Renders a code as an image. Shared by `BarcodeView`, the Lock Screen arrival
/// notifications and the Home Screen widget, so all draw exactly the same barcode.
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

    /// The bare code at one pixel a module, as the generator draws it before
    /// scaling it to a size, for reading its modules (`BarcodeModules`); nil if
    /// the code is not valid for `type`.
    public static func unscaled(_ code: String, type: BarcodeType) -> CGImage? {
        guard let metadataType = BarcodeMapper.mapBarcodeTypeToMetadataObjectType(type) else {
            return nil
        }
        return RSUnifiedCodeGenerator.shared.generateCode(code, machineReadableCodeObjectType: metadataType.rawValue)?.cgImage
    }

    /// The code at `size` pixels on white, with a `margin` pixel quiet zone round
    /// it. One opaque image, so nothing can tint the white away from the bars.
    public static func onWhite(_ code: String, type: BarcodeType, size: CGSize, margin: CGFloat) -> UIImage? {
        guard let image = make(code, type: type, size: size) else { return nil }
        let canvas = CGSize(width: size.width + margin * 2, height: size.height + margin * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))
            image.draw(in: CGRect(origin: CGPoint(x: margin, y: margin), size: size))
        }
    }

    /// PNG of the code on a white card with a quiet zone, ready for a scanner.
    public static func pngOnWhite(_ code: String, type: BarcodeType) -> Data? {
        let codeSize = type.isSquare ? CGSize(width: 600, height: 600) : CGSize(width: 1_200, height: 400)
        return onWhite(code, type: type, size: codeSize, margin: 60)?.pngData()
    }
}
