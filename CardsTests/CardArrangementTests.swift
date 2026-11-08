@testable import Cards
import CoreLocation
import Foundation
import Testing

/// Searching and ordering the Cards tab (CARD-11), the card for where you are
/// (SET-3) and dragging a card to a new place (CARD-10).
struct CardArrangementTests {
    /// Where the tests stand: Notting Hill Gate.
    private static let here = CLLocation(latitude: 51.5091, longitude: -0.1963)

    /// A place whose middle is `metres` north of `here`.
    private static func place(_ name: String, north metres: Double, radius: Double = 100) -> CardLocation {
        CardLocation(
            name: name,
            latitude: here.coordinate.latitude + metres / 111_320,
            longitude: here.coordinate.longitude,
            radius: radius
        )
    }

    /// A card named by its code, last viewed `viewed` seconds after 1970.
    private static func card(_ code: String, order: Int, viewed: TimeInterval? = nil, places: [CardLocation] = []) -> CardItem {
        CardItem(code: code, name: code, order: order, locations: places, lastViewed: viewed.map(Date.init(timeIntervalSince1970:)))
    }

    private static func codes(_ cards: [CardItem], by order: CardSortOrder, search: String = "", near location: CLLocation? = nil) -> [String] {
        CardArrangement.arranged(cards, by: order, search: search, near: location).map(\.code)
    }

    @Test func customOrderFollowsEachCardsOrderAndKeepsTiesAsGiven() {
        let cards = [Self.card("c", order: 2), Self.card("a", order: 0), Self.card("b1", order: 1), Self.card("b2", order: 1)]
        #expect(Self.codes(cards, by: .custom) == ["a", "b1", "b2", "c"])
    }

    @Test func lastViewedPutsTheMostRecentFirstThenCardsNeverOpenedInCustomOrder() {
        let cards = [
            Self.card("never-b", order: 3),
            Self.card("old", order: 0, viewed: 100),
            Self.card("never-a", order: 1),
            Self.card("new", order: 4, viewed: 300),
            Self.card("tie-b", order: 5, viewed: 200),
            Self.card("tie-a", order: 2, viewed: 200)
        ]
        #expect(Self.codes(cards, by: .lastViewed) == ["new", "tie-a", "tie-b", "old", "never-a", "never-b"])
    }

    @Test func lastViewedIsCustomOrderWhenNoCardHasBeenOpened() {
        let cards = [Self.card("b", order: 1), Self.card("a", order: 0)]
        #expect(Self.codes(cards, by: .lastViewed) == ["a", "b"])
    }

    @Test func locationPutsTheNearestPlaceFirstThenCardsWithoutPlacesInCustomOrder() {
        let cards = [
            Self.card("none-b", order: 4),
            Self.card("far", order: 0, places: [Self.place("Far", north: 2_000)]),
            Self.card("none-a", order: 1),
            Self.card("near", order: 3, places: [Self.place("Near", north: 400)]),
            // Its nearer place counts: 150 m to the edge, against 300 m for "near".
            Self.card("nearer", order: 2, places: [Self.place("Far away", north: 5_000), Self.place("Close", north: 250)])
        ]
        #expect(Self.codes(cards, by: .location, near: Self.here) == ["nearer", "near", "far", "none-a", "none-b"])
    }

    @Test func locationIsCustomOrderWhenWhereYouAreIsUnknown() {
        let cards = [Self.card("b", order: 1, places: [Self.place("B", north: 10)]), Self.card("a", order: 0)]
        #expect(Self.codes(cards, by: .location) == ["a", "b"])
    }

    @Test func locationPrefersTheNearerMiddleInsidePlacesAndKeepsCustomOrderOnATie() {
        let cards = [
            Self.card("inside-near-edge", order: 0, places: [Self.place("Edge", north: 80)]),
            Self.card("twin-b", order: 2, places: [Self.place("Twin", north: 20)]),
            Self.card("twin-a", order: 1, places: [Self.place("Twin", north: 20)])
        ]
        #expect(Self.codes(cards, by: .location, near: Self.here) == ["twin-a", "twin-b", "inside-near-edge"])
    }

    @Test(arguments: [
        ("joe", "Joe's Market", true),
        ("MARK", "Joe's Market", true),
        ("cafe", "Local Roast Café", true),
        ("CAFÉ", "Local Roast Cafe", true),
        ("Joe’s", "Joe's Market", true),
        ("joe's", "Joe’s Market", true),
        ("  honeycomb  ", "Honeycomb Rewards", true),
        ("", "Green Leaf Pharmacy", true),
        (" \n", "Green Leaf Pharmacy", true),
        ("pharmacy", "Joe's Market", false),
        ("Markets", "Joe's Market", false)
    ])
    func searchMatchesNamesIgnoringCaseAccentsAndCurlyApostrophes(search: String, name: String, matches: Bool) {
        #expect(CardArrangement.name(name, matches: search) == matches)
    }

    @Test func searchFiltersBeforeTheCardsAreOrdered() {
        let cards = [
            Self.card("Local Roast Coffee", order: 1, viewed: 10),
            Self.card("Joe's Market", order: 0, viewed: 30),
            Self.card("Local Roast Portobello", order: 2, viewed: 20)
        ]
        #expect(Self.codes(cards, by: .lastViewed, search: "roast") == ["Local Roast Portobello", "Local Roast Coffee"])
        #expect(Self.codes(cards, by: .custom, search: "corner grocer").isEmpty)
    }

    /// A search finds a card by its notes too, read as a name is (CARD-14).
    @Test func searchMatchesNotesToo() {
        let honeycomb = CardItem(code: "9988776655443", name: "Honeycomb Rewards", order: 0, notes: "Points reset each January.")
        let localRoast = CardItem(code: "1234567890128", name: "Local Roast Coffee", order: 1, notes: "Ask for a stamp at the till.")
        let joes = CardItem(code: "482019375610284", name: "Joe's Market", order: 2)
        let cards = [honeycomb, localRoast, joes]
        #expect(Self.codes(cards, by: .custom, search: "january") == ["9988776655443"])
        #expect(Self.codes(cards, by: .custom, search: " STAMP ") == ["1234567890128"])
        #expect(Self.codes(cards, by: .custom, search: "joe") == ["482019375610284"])
        #expect(Self.codes(cards, by: .custom, search: "receipt").isEmpty)
        #expect(Self.codes(cards, by: .custom).count == 3)
    }

    @Test func onlyASearchWithTextFilters() {
        #expect(!CardArrangement.isFiltering(""))
        #expect(!CardArrangement.isFiltering("  \n"))
        #expect(CardArrangement.isFiltering(" a "))
    }

    @Test func theCardHereIsTheOneWhosePlaceYouAreNearestTheMiddleOf() {
        let cards = [
            // 20 m away, so nearer than any edge but not a place you are in.
            Self.card("outside", order: 0, places: [Self.place("Next door", north: 120)]),
            Self.card("inside-big", order: 1, places: [Self.place("Big", north: 150, radius: 200)]),
            Self.card("inside-small", order: 2, places: [Self.place("Far", north: 3_000), Self.place("Small", north: 30, radius: 50)])
        ]
        #expect(CardArrangement.cardHere(in: cards, at: Self.here)?.code == "inside-small")
    }

    @Test func theCardHereOnATieIsTheFirstInCustomOrder() {
        let cards = [
            Self.card("b", order: 1, places: [Self.place("Shop", north: 0)]),
            Self.card("a", order: 0, places: [Self.place("Shop", north: 0)])
        ]
        #expect(CardArrangement.cardHere(in: cards, at: Self.here)?.code == "a")
    }

    @Test func thereIsNoCardHereOutsideEveryPlaceOrWhenWhereYouAreIsUnknown() {
        let outside = [Self.card("near", order: 0, places: [Self.place("Shop", north: 150)]), Self.card("none", order: 1)]
        #expect(CardArrangement.cardHere(in: outside, at: Self.here) == nil)
        let inside = [Self.card("in", order: 0, places: [Self.place("Shop", north: 0)])]
        #expect(CardArrangement.cardHere(in: inside, at: nil) == nil)
        #expect(CardArrangement.cardHere(in: [], at: Self.here) == nil)
    }

    @Test func aMovedCardTakesThePlaceOfTheOneItIsDroppedOn() {
        let items = ["a", "b", "c", "d"]
        #expect(CardArrangement.moving(items, from: 0, to: 2) == ["b", "c", "a", "d"])
        #expect(CardArrangement.moving(items, from: 3, to: 1) == ["a", "d", "b", "c"])
        #expect(CardArrangement.moving(items, from: 0, to: 3) == ["b", "c", "d", "a"])
        #expect(CardArrangement.moving(items, from: 1, to: 1) == items)
        #expect(CardArrangement.moving(items, from: 4, to: 0) == items)
    }

    @Test func storedSettingsKeepTheirNames() {
        // Kept in UserDefaults on every device, and the Settings switch reads the same key.
        #expect(DeviceSettings.showsCardWhereYouAreKey == "showsCardWhereYouAre")
        #expect(DeviceSettings.cardSortOrderKey == "cardSortOrder")
        #expect(CardSortOrder.allCases.map(\.rawValue) == ["lastViewed", "custom", "location"])
    }
}
