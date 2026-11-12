import Foundation

public enum BarcodeType: String, Codable, CaseIterable, Hashable, Sendable {
    case code128 = "Code 128"
    case code39  = "Code 39"
    case qrCode  = "QR Code"
    case ean8    = "EAN-8"
    case ean13   = "EAN-13"
    case code93  = "Code 93"
    case upce    = "UPC-E"
    case aztec   = "Aztec"
    case pdf417  = "PDF 417"

    /// 2D codes that are square rather than a wide strip of bars.
    public var isSquare: Bool {
        self == .qrCode || self == .aztec
    }

    /// The name people see, in the barcode type picker and in VoiceOver hints.
    /// The raw value is what cards store and exports carry, so it never changes
    /// with the language; in English the two are the same.
    public var displayName: LocalizedStringResource {
        switch self {
        case .code128:
            LocalizedStringResource(
                "Code 128",
                comment: "Barcode format in the barcode type picker. A standard name: keep it unless your language writes it differently."
            )
        case .code39:
            LocalizedStringResource(
                "Code 39",
                comment: "Barcode format in the barcode type picker. A standard name: keep it unless your language writes it differently."
            )
        case .qrCode:
            LocalizedStringResource(
                "QR Code",
                comment: "Barcode format in the barcode type picker: the square 2D code. Use the usual name for a QR code in your language."
            )
        case .ean8:
            LocalizedStringResource(
                "EAN-8",
                comment: "Barcode format in the barcode type picker. A standard name: keep it as it is."
            )
        case .ean13:
            LocalizedStringResource(
                "EAN-13",
                comment: "Barcode format in the barcode type picker. A standard name: keep it as it is."
            )
        case .code93:
            LocalizedStringResource(
                "Code 93",
                comment: "Barcode format in the barcode type picker. A standard name: keep it unless your language writes it differently."
            )
        case .upce:
            LocalizedStringResource(
                "UPC-E",
                comment: "Barcode format in the barcode type picker. A standard name: keep it as it is."
            )
        case .aztec:
            LocalizedStringResource(
                "Aztec",
                comment: "Barcode format in the barcode type picker: the square 2D Aztec Code. Keep it unless your language writes it differently."
            )
        case .pdf417:
            LocalizedStringResource(
                "PDF 417",
                comment: "Barcode format in the barcode type picker: the stacked 2D PDF417 code, not a PDF file. Keep it as it is."
            )
        }
    }
}
