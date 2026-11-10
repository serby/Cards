import CoreLocation
import Foundation

/// A card as it travels in a share link (SHARE-1): everything someone needs to
/// add it, and nothing about the person who shared it, such as when they added
/// it, where it sits in their list or when they last opened it.
///
/// The link carries it after the "#" as JSON in base64url without padding, so
/// browsers never send it to the website, with a "." every `segmentLength`
/// characters. `v` is the format's version. Readers
/// ignore fields they don't know, so a new optional field keeps version 1; only
/// a change an older reader would get wrong raises it, and older readers then
/// treat the link as holding no card.
public struct SharedCard: Hashable, Sendable {
    /// One of the card's places, without the id it has in the sharer's app.
    public struct Place: Hashable, Sendable {
        public var name: String
        public var latitude: CLLocationDegrees
        public var longitude: CLLocationDegrees
        /// In metres.
        public var radius: CLLocationDistance

        public init(name: String, latitude: CLLocationDegrees, longitude: CLLocationDegrees, radius: CLLocationDistance) {
            self.name = name
            self.latitude = latitude
            self.longitude = longitude
            self.radius = radius
        }
    }

    /// The format version this build writes and reads.
    public static let version = 1
    /// The longest payload read, in characters. A card with a dozen places is
    /// under 2,000, so anything much longer is not one of ours.
    public static let maximumPayloadLength = 16_384
    /// The longest run of characters in a payload without a ".". Link detectors
    /// end a link at a longer one: iOS's `NSDataDetector` keeps a fragment of
    /// 301 unbroken characters and drops one of 302, so in WhatsApp a card with
    /// places was a link only up to its "#". Readers ignore the dots.
    public static let segmentLength = 100

    public var name: String
    public var code: String
    public var barcodeType: BarcodeType
    public var color: CardColor
    /// The card's icon, an SF Symbol name, or nil for none (CARD-12).
    public var icon: String?
    public var places: [Place]
    public var notifiesOnArrival: Bool

    public init(
        name: String,
        code: String,
        barcodeType: BarcodeType = .code128,
        color: CardColor = .standard,
        icon: String? = nil,
        places: [Place] = [],
        notifiesOnArrival: Bool = true
    ) {
        self.name = name
        self.code = code
        self.barcodeType = barcodeType
        self.color = color
        self.icon = icon
        self.places = places
        self.notifiesOnArrival = notifiesOnArrival
    }
}

public extension SharedCard {
    /// What `card` shares.
    init(_ card: CardItem) {
        self.init(
            name: card.name,
            code: card.code,
            barcodeType: card.getBarcodeType(),
            color: card.getColor(),
            icon: card.icon,
            places: card.locations.map { Place(name: $0.name, latitude: $0.latitude, longitude: $0.longitude, radius: $0.radius) },
            notifiesOnArrival: card.notifiesOnArrival
        )
    }

    /// The text after the "#" in a share link.
    var payload: String {
        let encoder = JSONEncoder()
        // Sorted, so the same card always makes the same link.
        encoder.outputFormatting = .sortedKeys
        // Encoding plain strings and numbers cannot fail.
        let json = (try? encoder.encode(self)) ?? Data()
        let base64URL = json.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return stride(from: 0, to: base64URL.count, by: Self.segmentLength)
            .map { start in
                let from = base64URL.index(base64URL.startIndex, offsetBy: start)
                let to = base64URL.index(from, offsetBy: Self.segmentLength, limitedBy: base64URL.endIndex) ?? base64URL.endIndex
                return String(base64URL[from..<to])
            }
            .joined(separator: ".")
    }

    /// The card a payload holds, or nil when it holds none: it is empty, too
    /// long, not base64url, not JSON, from a newer format, or a card without a
    /// name or a code. The dots between segments are skipped, and a payload
    /// without them, as links made before 1.4 had, reads the same.
    init?(payload: String) {
        guard !payload.isEmpty, payload.count <= Self.maximumPayloadLength else { return nil }
        var base64 = payload
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let json = Data(base64Encoded: base64),
              let card = try? JSONDecoder().decode(Self.self, from: json) else {
            return nil
        }
        self = card
    }

    /// The card to add, by the import rules (DATA-3): its code trimmed, and
    /// placed after `existing`, unless `existing` already has its code, in
    /// which case `alreadyHere` counts it and nothing is added.
    func importResult(existing: [CardItem], addedAt: Date) -> CardImport.Result {
        CardImport.cards(from: [CardItemDTO(from: cardItem(addedAt: addedAt))], existing: existing)
    }

    /// A new card with these details, added at `addedAt`.
    func cardItem(addedAt: Date) -> CardItem {
        CardItem(
            timestamp: addedAt,
            code: code,
            name: name,
            barcodeType: barcodeType,
            color: color,
            locations: locations,
            notifiesOnArrival: notifiesOnArrival,
            icon: icon
        )
    }

    /// The places as locations of the recipient's own, each with a new id.
    var locations: [CardLocation] {
        places.map { CardLocation(name: $0.name, latitude: $0.latitude, longitude: $0.longitude, radius: $0.radius) }
    }
}

extension SharedCard: Codable {
    private enum CodingKeys: String, CodingKey {
        case version = "v"
        case name, code, type, color, icon, places, notifiesOnArrival
    }

    private struct NotACard: Error {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(Int.self, forKey: .version) == Self.version else { throw NotACard() }
        name = try container.decode(String.self, forKey: .name).trimmingCharacters(in: .whitespacesAndNewlines)
        code = try container.decode(String.self, forKey: .code).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !code.isEmpty else { throw NotACard() }
        // Read tolerantly, as an export is: an unknown type or colour from a newer build falls back.
        barcodeType = try container.decodeIfPresent(String.self, forKey: .type).flatMap(BarcodeType.init(rawValue:)) ?? .code128
        color = CardColor.stored(try container.decodeIfPresent(String.self, forKey: .color))
        icon = try container.decodeIfPresent(String.self, forKey: .icon).flatMap { $0.isEmpty ? nil : $0 }
        places = try (container.decodeIfPresent([Place].self, forKey: .places) ?? []).compactMap(\.valid)
        notifiesOnArrival = try container.decodeIfPresent(Bool.self, forKey: .notifiesOnArrival) ?? true
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.version, forKey: .version)
        try container.encode(name, forKey: .name)
        try container.encode(code, forKey: .code)
        try container.encode(barcodeType.rawValue, forKey: .type)
        try container.encode(color.rawValue, forKey: .color)
        try container.encodeIfPresent(icon, forKey: .icon)
        if !places.isEmpty {
            try container.encode(places, forKey: .places)
        }
        try container.encode(notifiesOnArrival, forKey: .notifiesOnArrival)
    }
}

extension SharedCard.Place: Codable {
    /// The place if it is somewhere on Earth, with its radius brought into the
    /// range the picker offers; nil otherwise.
    var valid: Self? {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude), radius.isFinite else { return nil }
        var place = self
        place.radius = min(max(radius, CardLocation.radiusRange.lowerBound), CardLocation.radiusRange.upperBound)
        return place
    }
}
