import Foundation

/// Where reading a photo or a file for its barcode has got to, on the add
/// form (CARD-13).
public enum BarcodeImportStatus: Hashable, Sendable {
    /// Nothing chosen yet, or the last barcode found has been filled in.
    case ready
    /// A photo or file is being read.
    case reading
    /// Several barcodes were found, and the person picks the one for the card.
    case choosing([FoundBarcode])
    /// The last photo or file gave no barcode the app can show, and says why.
    case failed(BarcodeReading)
}

public extension BarcodeReading {
    /// What the form says when this reading gave nothing to fill in, or nil
    /// when it found a barcode. VoiceOver announces the same words.
    var problem: String? {
        switch self {
        case .found:
            nil
        case .nothing:
            "No barcode found. Try a picture where the whole barcode is sharp."
        case .unsupported(let kinds) where kinds.isEmpty:
            "Card Barcodes cannot show this kind of barcode."
        case .unsupported(let kinds):
            "Card Barcodes cannot show \(kinds.formatted(.list(type: .or))) codes."
        case .unreadable:
            "That photo or file could not be read."
        }
    }
}

public extension FoundBarcode {
    /// What VoiceOver says once the barcode fills in the form.
    var announcement: String {
        "Barcode found: \(type.rawValue). Its code is filled in."
    }
}
