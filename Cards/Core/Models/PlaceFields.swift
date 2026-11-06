import Foundation

/// What MapKit says about a place, cut down to the fields Cards names it from.
/// The live `PlaceSearch` copies them out of a map item or a placemark, so the
/// naming rule (PLACE-10) is plain code that tests can reach.
public struct PlaceFields: Equatable, Sendable {
    /// MapKit's own name for the place: a business, a landmark, a street
    /// address, a postcode or a town.
    public var name: String?
    /// Whether MapKit files the place as a point of interest, such as a shop,
    /// a café or a station.
    public var isPointOfInterest: Bool
    /// The street, without a house number, when MapKit's name is a street address.
    public var street: String?
    /// The district round the place, or else its town.
    public var area: String?

    public init(name: String? = nil, isPointOfInterest: Bool = false, street: String? = nil, area: String? = nil) {
        self.name = name
        self.isPointOfInterest = isPointOfInterest
        self.street = street
        self.area = area
    }

    /// What to call the place: a point of interest's own name, such as "Joe's
    /// Market"; else the street and area, such as "Portobello Road, Kensington
    /// and Chelsea"; else MapKit's name, such as a postcode, a town or a park;
    /// else the area. Nil when MapKit gave nothing to go on.
    public var placeName: String? {
        if isPointOfInterest, let name = name.nonBlank {
            return name
        }
        if let street = street.nonBlank {
            guard let area = area.nonBlank, !street.localizedCaseInsensitiveContains(area) else { return street }
            return "\(street), \(area)"
        }
        return name.nonBlank ?? area.nonBlank
    }
}

public extension PlaceFields {
    /// From a placemark's fields, which is what iOS 18 to 25 offer, both from
    /// the reverse geocoder and in a search result's `placemark`.
    ///
    /// MapKit's name is a street address when it contains the street, as
    /// "191 Portobello Road" does, unless it is also an area of interest, as
    /// "Notting Hill Gate" is: then the name names the place.
    init(
        name: String?,
        thoroughfare: String?,
        subLocality: String?,
        locality: String?,
        areasOfInterest: [String],
        isPointOfInterest: Bool
    ) {
        let isAddress: Bool = if let thoroughfare = thoroughfare.nonBlank {
            name.nonBlank.map { $0.contains(thoroughfare) && !areasOfInterest.contains($0) } ?? true
        } else {
            false
        }
        self.init(
            name: name,
            isPointOfInterest: isPointOfInterest,
            street: isAddress ? thoroughfare : nil,
            area: subLocality.nonBlank ?? locality.nonBlank
        )
    }

    /// From the fields a map item has on iOS 26 and later, which has no
    /// placemark: its name, its short address, such as "191 Portobello Road,
    /// London", and its city, such as "Kensington and Chelsea, London".
    ///
    /// The short address, less the parts it shares with the city, is the street
    /// address. MapKit's name is a street address when it is one of those parts.
    init(name: String?, shortAddress: String?, cityName: String?, isPointOfInterest: Bool) {
        let cityParts = Self.parts(of: cityName)
        let addressParts = Self.parts(of: shortAddress).filter { !cityParts.contains($0) }
        let addressLine: String? = if let name = name.nonBlank {
            addressParts.contains(name) ? name : nil
        } else {
            addressParts.last
        }
        self.init(
            name: name,
            isPointOfInterest: isPointOfInterest,
            street: addressLine.map(Self.withoutHouseNumber),
            area: cityParts.first
        )
    }

    private static func parts(of text: String?) -> [String] {
        (text ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// "191 Portobello Road" becomes "Portobello Road", and "52–74 Notting Hill
    /// Gate" becomes "Notting Hill Gate": a place is a circle round a spot, so
    /// the street names it better than one door does.
    private static func withoutHouseNumber(_ line: String) -> String {
        guard let space = line.firstIndex(of: " "), line.first?.isNumber == true else { return line }
        let street = line[space...].trimmingCharacters(in: .whitespaces)
        return street.isEmpty ? line : street
    }
}

private extension Optional<String> {
    /// The text, trimmed, or nil when there is none.
    var nonBlank: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
