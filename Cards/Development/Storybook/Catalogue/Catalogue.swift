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

extension CardColor {
    static var allNames: [String] {
        allCases.map(\.rawValue)
    }

    static func named(_ raw: String) -> Self {
        stored(raw)
    }
}

/// Knobs for a card's distance to its nearest location, shared by every story
/// that shows one so they all read the same.
enum ProximityKnobs {
    static let hasLocation = "Has location"
    static let place = "Place"
    static let distance = "Distance (m)"

    /// With `optional`, a "Has location" toggle decides whether there is one at all.
    static func knobs(optional: Bool = true, place: String = "Westway", distance: Double = 350) -> [StoryKnob] {
        (optional ? [.toggle(hasLocation, true)] : []) + [
            .text(Self.place, place),
            .number(Self.distance, distance, in: 0...10_000, step: 50)
        ]
    }
}

extension KnobValues {
    /// The proximity the shared knobs describe; nil when "Has location" is off.
    func proximity(optional: Bool = true) -> CardProximity? {
        if optional && !bool(ProximityKnobs.hasLocation) { return nil }
        return CardProximity(placeName: string(ProximityKnobs.place), distance: number(ProximityKnobs.distance))
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
