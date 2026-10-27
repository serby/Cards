import CardsCore

public extension Story {
    /// Every story, in sidebar order. Add new entries to one of the lists below.
    static var all: [Self] {
        componentStories + screenStories
    }
}

extension BarcodeType {
    static var allNames: [String] {
        allCases.map(\.rawValue)
    }

    static func named(_ raw: String) -> Self {
        Self(rawValue: raw) ?? .code128
    }
}

/// A representative code for each symbology, so the gallery shows real
/// barcodes rather than a wall of generation failures.
enum SampleCode {
    static func valid(for type: BarcodeType) -> String {
        switch type {
        case .code128:
            return "ABC-1234"
        case .code39:
            return "ABC1234"
        case .code93:
            return "ABC1234"
        case .ean8:
            return "96385074"
        case .ean13:
            return "5012345678900"
        case .upce:
            return "01234565"
        case .qrCode:
            return "https://serby.net"
        case .aztec:
            return "Cards"
        case .pdf417:
            return "Cards 1234"
        }
    }
}
