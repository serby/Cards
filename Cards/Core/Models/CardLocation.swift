import CoreLocation
import Foundation

/// A place a card is used: a circle on the map. A card can have any number.
public struct CardLocation: Codable, Hashable, Identifiable, Sendable {
    /// The radius a location gets when added by postcode, in metres.
    public static let defaultRadius: CLLocationDistance = 200
    /// The radii the location picker offers, in metres.
    public static let radiusRange: ClosedRange<CLLocationDistance> = 50...1_000

    public var id: UUID
    public var name: String
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    /// In metres.
    public var radius: CLLocationDistance

    public init(
        id: UUID = UUID(),
        name: String,
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        radius: CLLocationDistance = Self.defaultRadius
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Metres from `location` to the edge of the circle; 0 when inside it.
    public func distance(from location: CLLocation) -> CLLocationDistance {
        max(0, distanceToCentre(from: location) - radius)
    }

    /// Metres from `location` to the middle of the circle, which decides
    /// between places you are inside.
    public func distanceToCentre(from location: CLLocation) -> CLLocationDistance {
        location.distance(from: CLLocation(latitude: latitude, longitude: longitude))
    }

    /// Apple Maps with a pin at the place, labelled with its name (PLACE-9).
    public var mapsURL: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.path = "/"
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: name)
        ]
        return components.url
    }
}

public extension CLLocationDistance {
    /// This distance as a measurement in metres, for `Text(_:format:)` with
    /// `.distance` or `.radius`.
    var metres: Measurement<UnitLength> {
        Measurement(value: self, unit: .meters)
    }
}

/// Views format with these rather than with ready-made strings, so the text
/// follows the locale SwiftUI renders in (`\.locale`), not just the device's.
public extension FormatStyle where Self == Measurement<UnitLength>.FormatStyle {
    /// A distance to somewhere, in the units the locale uses for roads:
    /// "350 m" and "1,5 km" in Germany, "400 yd" and "0.93 mi" in the UK.
    static var distance: Self {
        .measurement(width: .abbreviated, usage: .road)
    }

    /// A radius as set on the slider, always in metres, as the slider steps
    /// in metres: "200 m".
    static var radius: Self {
        .measurement(width: .abbreviated, usage: .asProvided)
    }

    /// `distance` with its unit written out, for VoiceOver: "350 metres",
    /// not "350 m", which speech reads inconsistently from one language to
    /// another.
    static var spokenDistance: Self {
        .measurement(width: .wide, usage: .road)
    }

    /// `radius` with its unit written out, for VoiceOver: "200 metres".
    static var spokenRadius: Self {
        .measurement(width: .wide, usage: .asProvided)
    }
}

/// How far the user is from the nearest of a card's locations.
public struct CardProximity: Hashable, Sendable {
    public let placeName: String
    /// Metres to the edge of the nearest location; 0 when inside it.
    public let distance: CLLocationDistance

    public init(placeName: String, distance: CLLocationDistance) {
        self.placeName = placeName
        self.distance = distance
    }

    public var isHere: Bool { distance == 0 }
}

/// One of a card's places, and how far away it is when the app knows where you are.
public struct NearbyPlace: Hashable, Sendable, Identifiable {
    public let location: CardLocation
    /// Nil while where you are is unknown.
    public let proximity: CardProximity?

    public init(location: CardLocation, proximity: CardProximity?) {
        self.location = location
        self.proximity = proximity
    }

    public var id: UUID { location.id }
}

public extension Sequence<CardLocation> {
    /// The nearest location to `location`, or `nil` if either is missing. Inside
    /// more than one, the one whose middle you are nearer, as `nearest` orders them.
    func proximity(to location: CLLocation?) -> CardProximity? {
        nearest(1, to: location).first?.proximity
    }

    /// Up to `limit` of these places, nearest first, each with its distance
    /// (PLACE-9). Distances are to the edge of a place's circle, so every place
    /// you are inside is 0 away and counts as here; between those, the one whose
    /// middle you are nearer comes first. Equal distances keep this order.
    /// Without `location`, the first `limit` in this order, with no distances.
    func nearest(_ limit: Int, to location: CLLocation?) -> [NearbyPlace] {
        guard limit > 0 else { return [] }
        guard let location else {
            return prefix(limit).map { NearbyPlace(location: $0, proximity: nil) }
        }
        return enumerated()
            .map { offset, place in
                (place: place, edge: place.distance(from: location), centre: place.distanceToCentre(from: location), offset: offset)
            }
            .sorted { ($0.edge, $0.centre, $0.offset) < ($1.edge, $1.centre, $1.offset) }
            .prefix(limit)
            .map { NearbyPlace(location: $0.place, proximity: CardProximity(placeName: $0.place.name, distance: $0.edge)) }
    }
}

/// A place found from a search such as a postcode.
public struct PlaceMatch: Hashable, Sendable {
    public let name: String
    public let latitude: CLLocationDegrees
    public let longitude: CLLocationDegrees

    public init(name: String, latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
