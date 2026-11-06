import CoreLocation

/// A card's places as the card screen lists them below its face (PLACE-9): the
/// nearest few, nearest first, and how many more the card has. Pure: the card
/// screen's connector builds it from the card and where you are.
public struct CardPlaces: Hashable, Sendable {
    /// The most places the list shows.
    public static let limit = 5
    /// A card without places.
    public static let none = Self([], near: nil)

    /// The nearest `limit` places, nearest first, each with its distance. While
    /// where you are is unknown, the first `limit` in the card's order, without
    /// distances.
    public let listed: [NearbyPlace]
    /// How many more places the card has than `listed` shows.
    public let unlisted: Int

    public init(_ locations: [CardLocation], near location: CLLocation?) {
        listed = locations.nearest(Self.limit, to: location)
        unlisted = locations.count - listed.count
    }

    /// How many places the card has.
    public var count: Int { listed.count + unlisted }

    /// Whether the card screen lists them: only with more than one, since the
    /// face's top panel already names the nearest (PLACE-6).
    public var isListed: Bool { count > 1 }

    /// Whether `listed` is nearest first with distances, rather than in the
    /// card's order because where you are is unknown.
    public var hasDistances: Bool { listed.contains { $0.proximity != nil } }
}
