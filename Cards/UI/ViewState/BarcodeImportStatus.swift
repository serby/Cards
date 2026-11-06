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
    var problem: LocalizedStringResource? {
        switch self {
        case .found:
            nil
        case .nothing:
            LocalizedStringResource(
                "No barcode found. Try a picture where the whole barcode is sharp.",
                comment: "Under Choose Photo and Choose File in the new card form, and read by VoiceOver, when the photo or file has no barcode."
            )
        case .unsupported(let kinds) where kinds.isEmpty:
            LocalizedStringResource(
                "Card Barcodes cannot show this kind of barcode.",
                comment: """
                    Under Choose Photo and Choose File in the new card form, and read by VoiceOver, when the photo or file has only a kind \
                    of barcode the app cannot draw. Card Barcodes is the app's name.
                    """
            )
        case .unsupported(let kinds):
            LocalizedStringResource(
                "Card Barcodes cannot show \(kinds, format: .list(type: .or)) codes.",
                comment: """
                    Under Choose Photo and Choose File in the new card form, and read by VoiceOver, when the photo or file has only kinds \
                    of barcode the app cannot draw. The argument is their standard names joined by “or”, as in “Data Matrix or ITF-14”. \
                    Card Barcodes is the app's name.
                    """
            )
        case .unreadable:
            LocalizedStringResource(
                "That photo or file could not be read.",
                comment: "Under Choose Photo and Choose File in the new card form, and read by VoiceOver, when the photo or file cannot be opened."
            )
        }
    }
}

public extension FoundBarcode {
    /// What VoiceOver says once the barcode fills in the form.
    var announcement: String {
        String(
            localized: "Barcode found: \(String(localized: type.displayName)). Its code is filled in.",
            comment: """
                VoiceOver announcement after a barcode read from a photo or a file fills in the new card form. The argument is its \
                format, as in “Barcode found: EAN-13”. The format's name is already translated and may contain the word code, as QR Code \
                and Code 128 do, so do not add one.
                """
        )
    }
}
