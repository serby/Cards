import AVFoundation

/// Between `BarcodeType` and AVFoundation's kinds of machine-readable code,
/// which the camera scanner reads and RSBarcodes draws. Apart from
/// `BarcodeType` because watchOS has no `AVMetadataObject`, and the Apple
/// Watch app shares `BarcodeType`.
public struct BarcodeMapper {
    public static func mapBarcodeTypeToMetadataObjectType(_ type: BarcodeType) -> AVMetadataObject.ObjectType? {
        switch type {
        case .code128:
            return .code128
        case .code39:
            return .code39
        case .qrCode:
            return .qr
        case .ean8:
            return .ean8
        case .ean13:
            return .ean13
        case .pdf417:
            return .pdf417
        case .upce:
            return .upce
        case .aztec:
            return .aztec
        case .code93:
            return .code93
        }
    }

    public static func mapMetadataObjectTypeToBarcodeType(_ metadataType: AVMetadataObject.ObjectType) -> BarcodeType? {
        switch metadataType {
        case .code128:
            return .code128
        case .code39:
            return .code39
        case .qr:
            return .qrCode
        case .ean8:
            return .ean8
        case .ean13:
            return .ean13
        case .pdf417:
            return .pdf417
        case .upce:
            return .upce
        case .aztec:
            return .aztec
        case .code93:
            return .code93
        default:
            return nil
        }
    }
}
