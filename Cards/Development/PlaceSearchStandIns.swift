import CoreLocation
import MapKit

/// Stand-ins for `PlaceSearch`, so stories, previews and tests never reach
/// MapKit. Every place is one of the made-up businesses in docs/LANGUAGE.md,
/// or a real street, area or postcode, which the guide allows.
public extension PlaceSearch {
    /// Searches `SamplePlace.all` by title and subtitle, and names a point by
    /// the sample business within 60 metres of it, or else as a street and area.
    static let sample = Self(
        suggest: { text, _ in PlaceSuggestion.samples(for: text) },
        place: { suggestion, _ in
            SamplePlace.all.first { $0.title == suggestion.title && $0.subtitle == suggestion.subtitle }?.match
        },
        bestMatch: { text, _ in
            SamplePlace.matching(text).first?.match
        },
        name: { coordinate in
            SamplePlace.name(at: coordinate)
        }
    )

    /// Finds nothing and names nothing, as MapKit does for "Corner Grocer".
    static let noMatches = Self.unavailable

    /// Never answers, so a story can show the search under way.
    static let searching = Self(
        suggest: { _, _ in try await waitForever([]) },
        place: { _, _ in try await waitForever(nil) },
        bestMatch: { _, _ in try await waitForever(nil) },
        name: { _ in try await waitForever(nil) }
    )

    /// Fails every question with `problem`, as MapKit does offline or when its
    /// servers are down.
    static func failing(_ problem: PlaceSearchError) -> Self {
        Self(
            suggest: { _, _ in throw problem },
            place: { _, _ in throw problem },
            bestMatch: { _, _ in throw problem },
            name: { _ in throw problem }
        )
    }

    private static func waitForever<T>(_ never: T) async throws -> T {
        try await Task.sleep(for: .seconds(86_400))
        return never
    }
}

/// A place the sample search knows, with what MapKit would say about it.
public struct SamplePlace: Sendable {
    public let title: String
    public let subtitle: String
    public let fields: PlaceFields
    public let latitude: CLLocationDegrees
    public let longitude: CLLocationDegrees

    /// The place as a search result, named as PLACE-10 says.
    public var match: PlaceMatch {
        PlaceMatch(name: fields.placeName ?? title, latitude: latitude, longitude: longitude)
    }

    private static func business(_ name: String, at subtitle: String, _ latitude: CLLocationDegrees, _ longitude: CLLocationDegrees) -> Self {
        Self(
            title: name,
            subtitle: subtitle,
            fields: PlaceFields(name: name, isPointOfInterest: true),
            latitude: latitude,
            longitude: longitude
        )
    }

    /// The made-up businesses where the screenshot cards are used, then a
    /// street, an area and a postcode.
    public static let all: [Self] = [
        business("Joe's Market Notting Hill", at: "Notting Hill Gate, London W11", 51.5090, -0.1960),
        business("Joe's Market Kensington", at: "Kensington High Street, London W8", 51.4990, -0.1990),
        business("Joe's Market Holland Park", at: "Holland Park Avenue, London W11", 51.5075, -0.2060),
        business("Local Roast Portobello", at: "Portobello Road, London W11", 51.5150, -0.2040),
        business("Local Roast Notting Hill", at: "Pembridge Road, London W11", 51.5100, -0.1975),
        business("Green Leaf Shepherd's Bush", at: "Uxbridge Road, London W12", 51.5072, -0.2213),
        business("Boulder Barn", at: "Acklam Road, London W10", 51.5203, -0.2094),
        business("Nordic Nest Wembley", at: "Wembley Park, London HA9", 51.5560, -0.2796),
        Self(
            title: "Portobello Road",
            subtitle: "London W11",
            fields: PlaceFields(name: "Portobello Road", street: "Portobello Road", area: "Notting Hill"),
            latitude: 51.5154,
            longitude: -0.2052
        ),
        Self(
            title: "Notting Hill",
            subtitle: "London",
            fields: PlaceFields(name: "Notting Hill", area: "Kensington and Chelsea"),
            latitude: 51.5110,
            longitude: -0.2000
        ),
        Self(
            title: "W11 3JE",
            subtitle: "London",
            fields: PlaceFields(name: "W11 3JE", area: "Kensington and Chelsea"),
            latitude: 51.5130,
            longitude: -0.2030
        )
    ]

    /// The places whose title or subtitle contains `text`, ignoring case and accents.
    public static func matching(_ text: String) -> [Self] {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        return all.filter {
            $0.title.localizedStandardContains(text) || $0.subtitle.localizedStandardContains(text)
        }
    }

    /// What a dropped pin at `coordinate` is called: the business within 60
    /// metres, or else a street and area, as MapKit names an address.
    public static func name(at coordinate: CLLocationCoordinate2D) -> String? {
        let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let nearest = all
            .filter(\.fields.isPointOfInterest)
            .min { $0.distance(from: point) < $1.distance(from: point) }
        if let nearest, nearest.distance(from: point) <= 60 {
            return nearest.match.name
        }
        return PlaceFields(name: "18 Pembridge Road", street: "Pembridge Road", area: "Notting Hill").placeName
    }

    private func distance(from point: CLLocation) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude).distance(from: point)
    }
}

public extension PlaceSuggestion {
    /// What the sample search suggests for `text`.
    static func samples(for text: String) -> [Self] {
        SamplePlace.matching(text).map { Self(query: text, title: $0.title, subtitle: $0.subtitle) }
    }
}
