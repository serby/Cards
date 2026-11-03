import CoreLocation
import Foundation

/// A place a card is used: a circle on the map. A card can have any number.
public struct CardLocation: Codable, Hashable, Identifiable, Sendable {
    /// The radius a location gets when added by postcode, in metres.
    public static let defaultRadius: CLLocationDistance = 200

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
        max(0, location.distance(from: CLLocation(latitude: latitude, longitude: longitude)) - radius)
    }
}

public extension CLLocationDistance {
    /// A distance to somewhere, in the user's units: "350 m", "0.4 mi".
    var distanceText: String {
        Measurement(value: self, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    /// A radius as set on the slider, in metres: "200 m".
    var radiusText: String {
        Measurement(value: self, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided))
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

public extension Sequence<CardLocation> {
    /// The nearest location to `location`, or `nil` if either is missing.
    func proximity(to location: CLLocation?) -> CardProximity? {
        guard let location else { return nil }
        return map { CardProximity(placeName: $0.name, distance: $0.distance(from: location)) }
            .min { $0.distance < $1.distance }
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
