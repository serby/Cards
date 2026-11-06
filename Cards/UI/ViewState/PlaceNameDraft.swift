import CoreLocation

/// The name the location picker is giving a place, and whose it is (PLACE-10).
///
/// MapKit names the place, from a search result or from the point under the
/// pin, until the person types a name of their own. From then on the name is
/// theirs: moving the place, searching or changing the radius leaves it alone.
/// Clearing the field hands it back to MapKit, which names the place the next
/// time it moves.
public struct PlaceNameDraft: Equatable, Sendable {
    /// What a place with no name is saved as.
    public static let unnamed = "Pinned location"

    /// How far the pin can move before MapKit's name no longer fits, so
    /// nudging the pin onto a shop front keeps the shop's name.
    public static let nudge: CLLocationDistance = 25

    /// What the name field shows.
    public private(set) var text: String
    /// True once the name is the person's own; MapKit then leaves it alone.
    public private(set) var isTyped: Bool
    /// Where the point MapKit named is, when the name is MapKit's.
    private var namedAt: Point?

    private struct Point: Equatable, Sendable {
        let latitude: CLLocationDegrees
        let longitude: CLLocationDegrees

        init(_ coordinate: CLLocationCoordinate2D) {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
        }

        func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
            CLLocation(latitude: latitude, longitude: longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
    }

    /// A new place, with no name until MapKit gives it one.
    public init() {
        text = ""
        isTyped = false
    }

    /// A place being changed. Its name counts as the person's own, unless it
    /// is the name of a place saved without one, which MapKit may replace.
    public init(editing name: String) {
        text = name
        isTyped = !Self.isBlank(name) && name != Self.unnamed
    }

    /// The person changed the field. Emptying it hands the name back to MapKit.
    /// The same text again, as a field may write back when it loses focus, is
    /// no change, so MapKit's name stays MapKit's.
    public mutating func type(_ newText: String) {
        guard newText != text else { return }
        text = newText
        isTyped = !Self.isBlank(newText)
        if !isTyped {
            namedAt = nil
        }
    }

    /// The widest map, in metres across, whose pin MapKit names. Wider than
    /// that, as while the map waits for your location, the pin marks a region
    /// rather than a place.
    public static let widestNamedMap: CLLocationDistance = 5_000

    /// Whether to ask MapKit for a name now the pin rests at `coordinate` on a
    /// map `mapWidth` metres across: not once the person has typed one, not
    /// while the map is too wide (or has not said how wide it is) for the pin
    /// to mark a place, and not after a nudge from the point MapKit last named.
    public func needsName(at coordinate: CLLocationCoordinate2D, mapWidth: CLLocationDistance?) -> Bool {
        guard !isTyped, let mapWidth, mapWidth <= Self.widestNamedMap else { return false }
        guard let namedAt else { return true }
        return namedAt.distance(to: coordinate) > Self.nudge
    }

    /// MapKit's name for the place at `coordinate`, or nil when it had none,
    /// which clears a name MapKit gave a spot the pin has left. Ignored once
    /// the person has typed a name.
    public mutating func name(_ name: String?, at coordinate: CLLocationCoordinate2D) {
        guard !isTyped else { return }
        text = name ?? ""
        namedAt = Point(coordinate)
    }

    /// The name the place is saved with.
    public var savedName: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.unnamed : trimmed
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
