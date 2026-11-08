import CoreLocation
import Foundation

/// Searching and ordering the cards on the Cards tab (CARD-11), choosing the
/// card for where you are (SET-3), and moving a card in custom order (CARD-10).
/// Pure: the list's connector applies it.
public enum CardArrangement {
    /// The cards whose names or notes match `search`, in `order`. `location` is
    /// where you are, for `.location`; without it, that order is custom order.
    ///
    /// Equal places keep custom order, and equal `order` values (two devices
    /// that renumbered before they synced) keep the order of `cards`.
    public static func arranged(
        _ cards: [CardItem],
        by order: CardSortOrder,
        search: String = "",
        near location: CLLocation? = nil
    ) -> [CardItem] {
        let custom = customOrder(cards.filter { card($0, matches: search) })
        switch order {
        case .custom:
            return custom
        case .lastViewed:
            let viewed = custom.compactMap { card in card.lastViewed.map { (card: card, date: $0) } }
            let recentFirst = stablySorted(viewed) { $0.date > $1.date }.map(\.card)
            return recentFirst + custom.filter { $0.lastViewed == nil }
        case .location:
            guard let location else { return custom }
            return byNearness(custom, to: location).map(\.card) + custom.filter(\.locations.isEmpty)
        }
    }

    /// Whether `name` contains `search`, ignoring case, accents and whether
    /// apostrophes and quotes are curly, since iOS curls them as you type. A
    /// blank search matches every name.
    public static func name(_ name: String, matches search: String) -> Bool {
        let wanted = query(search)
        return wanted.isEmpty
            || straightened(name).range(of: wanted, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    /// Whether `card`'s name or its notes (CARD-14) contain `search`, read as
    /// `name(_:matches:)` reads a name.
    public static func card(_ card: CardItem, matches search: String) -> Bool {
        name(card.name, matches: search) || card.notes.map { name($0, matches: search) } == true
    }

    /// Whether `search` leaves any card out: false while it is blank.
    public static func isFiltering(_ search: String) -> Bool {
        !query(search).isEmpty
    }

    /// The card to show in full where you are: of the cards with a place you
    /// are inside, the one whose place you are nearest the middle of, and the
    /// first in custom order on a tie. Nil when you are inside none of them, or
    /// where you are is unknown. It is the first card in location order.
    public static func cardHere(in cards: [CardItem], at location: CLLocation?) -> CardItem? {
        guard let location else { return nil }
        return byNearness(customOrder(cards), to: location).first { $0.edge == 0 }?.card
    }

    /// `items` with the one at `source` moved to `destination`, so a card
    /// dropped on another takes its place and the cards between shift along.
    /// Indices out of range leave `items` as they are.
    public static func moving<Element>(_ items: [Element], from source: Int, to destination: Int) -> [Element] {
        guard items.indices.contains(source), items.indices.contains(destination) else { return items }
        var moved = items
        moved.insert(moved.remove(at: source), at: destination)
        return moved
    }

    private static func customOrder(_ cards: [CardItem]) -> [CardItem] {
        stablySorted(cards) { $0.order < $1.order }
    }

    /// How near a card's nearest place is.
    private struct Nearness {
        let card: CardItem
        /// Metres to the edge of the place; 0 inside it.
        let edge: CLLocationDistance
        /// Metres to its middle, which decides between places you are inside.
        let centre: CLLocationDistance

        func isNearer(than other: Self) -> Bool {
            (edge, centre) < (other.edge, other.centre)
        }
    }

    /// The cards with places, nearest first: by the distance to the edge of
    /// their nearest place, then, between places you are inside, to its middle.
    private static func byNearness(_ cards: [CardItem], to location: CLLocation) -> [Nearness] {
        let near = cards.compactMap { card in
            card.locations
                .map { place in
                    let centre = location.distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude))
                    return Nearness(card: card, edge: max(0, centre - place.radius), centre: centre)
                }
                .min { $0.isNearer(than: $1) }
        }
        return stablySorted(near) { $0.isNearer(than: $1) }
    }

    /// `items` sorted, keeping their order where neither comes first.
    private static func stablySorted<Item>(_ items: [Item], by areInIncreasingOrder: (Item, Item) -> Bool) -> [Item] {
        items.enumerated()
            .sorted { lhs, rhs in
                if areInIncreasingOrder(lhs.element, rhs.element) { return true }
                if areInIncreasingOrder(rhs.element, lhs.element) { return false }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static let straightQuotes: [Character: Character] = ["‘": "'", "’": "'", "“": "\"", "”": "\""]

    private static func query(_ search: String) -> String {
        straightened(search.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func straightened(_ text: String) -> String {
        String(text.map { straightQuotes[$0] ?? $0 })
    }
}
