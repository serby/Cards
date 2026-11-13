import CoreLocation
import Foundation

/// What the Apple Watch app knows about a card (WATCH-1). The iPhone sends the
/// watch every card (`WatchSync`), so the watch works with iCloud Sync off and
/// with the phone out of reach. The card's barcode comes ready drawn, as a grid
/// of modules, because watchOS has no Core Image to draw one. Notes stay on the
/// phone.
public struct WatchCard: Hashable, Identifiable, Sendable {
    public let code: String
    public let name: String
    public let barcodeType: BarcodeType
    public let color: CardColor
    /// An SF Symbol's name (CARD-12), or nil for none.
    public let icon: String?
    public let locations: [CardLocation]
    /// The barcode the iPhone drew, or nil when the code cannot be drawn in its type.
    public let modules: BarcodeModules?

    public var id: String { code }

    public init(
        code: String,
        name: String,
        barcodeType: BarcodeType,
        color: CardColor,
        icon: String? = nil,
        locations: [CardLocation] = [],
        modules: BarcodeModules?
    ) {
        self.code = code
        self.name = name
        self.barcodeType = barcodeType
        self.color = color
        self.icon = icon
        self.locations = locations
        self.modules = modules
    }

    /// How far away the nearest of the card's places is, when `location` is known.
    public func proximity(to location: CLLocation?) -> CardProximity? {
        locations.proximity(to: location)
    }
}

/// Read tolerantly, as cards are (rule 6): a watch app older than the phone's
/// draws a barcode type it does not know from its modules all the same, and a
/// missing icon, place list or barcode reads as none.
extension WatchCard: Codable {
    private enum CodingKeys: String, CodingKey {
        case code
        case name
        case barcodeType
        case color
        case icon
        case locations
        case modules
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        barcodeType = try container.decodeIfPresent(String.self, forKey: .barcodeType).flatMap(BarcodeType.init(rawValue:)) ?? .code128
        color = try container.decodeIfPresent(CardColor.self, forKey: .color) ?? .standard
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        locations = try container.decodeIfPresent([CardLocation].self, forKey: .locations) ?? []
        modules = try container.decodeIfPresent(BarcodeModules.self, forKey: .modules)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(name, forKey: .name)
        try container.encode(barcodeType.rawValue, forKey: .barcodeType)
        try container.encode(color, forKey: .color)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encode(locations, forKey: .locations)
        try container.encodeIfPresent(modules, forKey: .modules)
    }
}

/// Everything the iPhone sends the watch (WATCH-1): every card, in the list's
/// own order (CARD-7), and the Distances choice (SET-4), so the watch writes
/// distances as the phone does.
public struct WatchSnapshot: Hashable, Sendable {
    public let cards: [WatchCard]
    public let distanceUnits: DistanceUnits

    public init(cards: [WatchCard], distanceUnits: DistanceUnits) {
        self.cards = cards
        self.distanceUnits = distanceUnits
    }
}

/// The units by their stored raw value, read with `DistanceUnits.stored`, so
/// a choice a newer phone adds reads as Automatic.
extension WatchSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case cards
        case distanceUnits
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cards = try container.decode([WatchCard].self, forKey: .cards)
        distanceUnits = DistanceUnits.stored(try container.decodeIfPresent(String.self, forKey: .distanceUnits))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cards, forKey: .cards)
        try container.encode(distanceUnits.rawValue, forKey: .distanceUnits)
    }
}

public extension WatchSnapshot {
    /// The application context's key for the encoded snapshot.
    static let cardsKey = "cards"
    /// The key, in the application context and in a file transfer's metadata,
    /// for when the phone sent it, so the watch keeps the newest whichever way
    /// it came.
    static let sentAtKey = "sentAt"
    /// The largest encoded snapshot sent as the application context, well
    /// under the 65,536 bytes WatchConnectivity takes in practice; a larger one
    /// goes as a file.
    static let contextLimit = 48 * 1_024

    /// The snapshot as it travels: JSON, compressed with LZFSE. The same cards
    /// always make the same bytes, so the phone can tell when nothing changed.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try (encoder.encode(self) as NSData).compressed(using: .lzfse) as Data
    }

    /// A snapshot as `encoded()` wrote it.
    init(encoded: Data) throws {
        let json = try (encoded as NSData).decompressed(using: .lzfse) as Data
        self = try JSONDecoder().decode(Self.self, from: json)
    }
}

/// Arriving at one of a card's places, as the watch sees it: the card and the place.
public struct WatchArrival: Hashable, Sendable {
    public let code: String
    public let placeID: UUID

    public init(code: String, placeID: UUID) {
        self.code = code
        self.placeID = placeID
    }

    /// Where the watch keeps the arrival a card was last opened for.
    public static let storageKey = "watchArrival"

    /// The arrival as the watch keeps it: the place's id, then the card's code,
    /// which may hold any character, so it goes last.
    public var stored: String {
        "\(placeID.uuidString) \(code)"
    }

    /// The arrival kept as `stored`, or nil for none or anything else.
    public init?(stored: String) {
        let parts = stored.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let placeID = UUID(uuidString: String(parts[0])), !parts[1].isEmpty else { return nil }
        self.init(code: String(parts[1]), placeID: placeID)
    }
}

public extension Collection<WatchCard> {
    /// The card for where you are (WATCH-4), by the rule the iPhone's "Here"
    /// follows (PLACE-6, SET-3): a card one of whose places you are inside. In
    /// several, the place whose middle you are nearest wins, and on a tie the
    /// card higher in the list. Nil when you are inside none, or where you are
    /// is unknown.
    func arrival(at location: CLLocation?) -> WatchArrival? {
        guard let location else { return nil }
        var best: (arrival: WatchArrival, centre: CLLocationDistance)?
        for card in self {
            guard let nearest = card.locations.nearest(1, to: location).first, nearest.proximity?.isHere == true else { continue }
            let centre = nearest.location.distanceToCentre(from: location)
            // Strictly nearer, so on a tie the card higher in the list stays.
            if best.map({ centre < $0.centre }) ?? true {
                best = (WatchArrival(code: card.code, placeID: nearest.location.id), centre)
            }
        }
        return best?.arrival
    }
}

/// Opens a card by itself once per arrival (WATCH-4), so that going back to the
/// list from it leaves the list showing. Pure: the watch's connector keeps one
/// and asks it each time the app comes to the front.
public struct WatchArrivals: Hashable, Sendable {
    /// The arrival a card was last opened for, until you are seen outside it.
    public private(set) var current: WatchArrival?

    public init(current: WatchArrival? = nil) {
        self.current = current
    }

    /// The code of the card to open at `location`: the card for where you are,
    /// unless it was opened for this arrival already. Being seen inside none
    /// of the places ends the arrival, so coming back opens the card again;
    /// an unknown location changes nothing.
    public mutating func cardToOpen(in cards: some Collection<WatchCard>, at location: CLLocation?) -> String? {
        guard let location else { return nil }
        let arrival = cards.arrival(at: location)
        guard arrival != current else { return nil }
        current = arrival
        return arrival?.code
    }
}
