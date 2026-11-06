import Foundation

/// A barcode found in a picture or on a page of a PDF, before it is known
/// whether the app can show it.
public struct DetectedBarcode: Hashable, Sendable {
    /// What the barcode holds.
    public var code: String
    /// The app's type for it, or nil when the app cannot draw this kind of barcode.
    public var type: BarcodeType?
    /// What this kind of barcode is called, such as "Data Matrix", or nil for
    /// a kind newer than this build.
    public var kind: String?

    public init(code: String, type: BarcodeType?, kind: String?) {
        self.code = code
        self.type = type
        self.kind = kind
    }

    /// A barcode of a type the app can draw, named after that type.
    public init(code: String, type: BarcodeType) {
        self.init(code: code, type: type, kind: type.rawValue)
    }
}

/// A barcode the app can show, ready to fill in a card's code and type.
public struct FoundBarcode: Identifiable, Hashable, Sendable {
    public var code: String
    public var type: BarcodeType

    public var id: String { "\(type.rawValue) \(code)" }

    public init(code: String, type: BarcodeType) {
        self.code = code
        self.type = type
    }
}

/// What reading a photo or a file for barcodes came to (CARD-13).
public enum BarcodeReading: Hashable, Sendable {
    /// One or more barcodes the app can show, each once, in the order they were found.
    case found([FoundBarcode])
    /// Only barcodes the app cannot show, with the names of their kinds, each
    /// once. Empty when none of the kinds has a name this build knows.
    case unsupported([String])
    /// No barcode at all.
    case nothing
    /// The photo or file could not be read: it could not be opened, it is
    /// neither a picture nor a PDF, or Vision could not look at it.
    case unreadable

    /// Sorts what was detected into what the person can use. A barcode the
    /// app can show wins over any it cannot, and a code seen twice, such as
    /// on two pages of a ticket, is offered once.
    public init(_ detected: [DetectedBarcode]) {
        var found: [FoundBarcode] = []
        var kinds: [String] = []
        for barcode in detected {
            if let type = barcode.type {
                let usable = FoundBarcode(code: barcode.code, type: type)
                if !found.contains(usable) {
                    found.append(usable)
                }
            } else if let kind = barcode.kind, !kinds.contains(kind) {
                kinds.append(kind)
            }
        }
        if !found.isEmpty {
            self = .found(found)
        } else if detected.contains(where: { $0.type == nil }) {
            self = .unsupported(kinds)
        } else {
            self = .nothing
        }
    }
}
