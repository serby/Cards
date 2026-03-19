import AVFoundation

public enum BarcodeType: String, Codable, CaseIterable, Hashable {
    case code128 = "Code 128"
    case code39  = "Code 39"
    case qrCode  = "QR Code"
    case ean8    = "EAN-8"
    case ean13   = "EAN-13"
    case code93  = "Code 93"
    case upce    = "UPC-E"
    case aztec   = "Aztec"
    case pdf417  = "PDF 417"
}

public struct BarcodeMapper {
    public static func mapBarcodeTypeToMetadataObjectType(_ type: BarcodeType) -> AVMetadataObject.ObjectType? {
        switch type {
        case .code128: return .code128
        case .code39:  return .code39
        case .qrCode:  return .qr
        case .ean8:    return .ean8
        case .ean13:   return .ean13
        case .pdf417:  return .pdf417
        case .upce:    return .upce
        case .aztec:   return .aztec
        case .code93:  return .code93
        }
    }

    public static func mapMetadataObjectTypeToBarcodeType(_ metadataType: AVMetadataObject.ObjectType) -> BarcodeType? {
        switch metadataType {
        case .code128: return .code128
        case .code39:  return .code39
        case .qr:      return .qrCode
        case .ean8:    return .ean8
        case .ean13:   return .ean13
        case .pdf417:  return .pdf417
        case .upce:    return .upce
        case .aztec:   return .aztec
        case .code93:  return .code93
        default:       return nil
        }
    }
}
