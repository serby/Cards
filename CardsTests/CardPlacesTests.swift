@testable import Cards
import CoreLocation
import Foundation
import Testing

/// PLACE-9: the card screen lists a card's nearest five places, with distances,
/// nearest first, or the first five in the card's order while where you are is unknown.
struct CardPlacesTests {
    /// Notting Hill Gate.
    private let here = CLLocation(latitude: 51.5091, longitude: -0.1963)

    /// In the card's order, which is not their order of distance from `here`:
    /// Notting Hill (inside, 0 m), Kensington (about 940 m), Holland Park (530 m),
    /// Earl's Court (1.7 km), Bayswater (525 m), Shepherd's Bush (1.4 km),
    /// Ladbroke Grove (1.2 km), each measured to the edge of its circle.
    private let places = [
        CardLocation(name: "Joe's Market Notting Hill", latitude: 51.5090, longitude: -0.1960, radius: 150),
        CardLocation(name: "Joe's Market Kensington", latitude: 51.4990, longitude: -0.1990),
        CardLocation(name: "Joe's Market Holland Park", latitude: 51.5075, longitude: -0.2058, radius: 150),
        CardLocation(name: "Joe's Market Earl's Court", latitude: 51.4920, longitude: -0.1934),
        CardLocation(name: "Joe's Market Bayswater", latitude: 51.5122, longitude: -0.1879, radius: 150),
        CardLocation(name: "Joe's Market Shepherd's Bush", latitude: 51.5046, longitude: -0.2187),
        CardLocation(name: "Joe's Market Ladbroke Grove", latitude: 51.5172, longitude: -0.2107, radius: 150)
    ]

    private func names(_ nearby: [NearbyPlace]) -> [String] {
        nearby.map(\.location.name)
    }

    @Test func nearestComeFirst() {
        let nearest = places.nearest(7, to: here)
        #expect(names(nearest) == [
            "Joe's Market Notting Hill",
            "Joe's Market Bayswater",
            "Joe's Market Holland Park",
            "Joe's Market Kensington",
            "Joe's Market Ladbroke Grove",
            "Joe's Market Shepherd's Bush",
            "Joe's Market Earl's Court"
        ])
        let distances = nearest.compactMap(\.proximity?.distance)
        #expect(distances.count == 7)
        #expect(distances == distances.sorted())
    }

    @Test func eachDistanceIsToTheEdgeOfItsPlace() throws {
        let kensington = try #require(places.nearest(7, to: here).first { $0.location.name == "Joe's Market Kensington" })
        let proximity = try #require(kensington.proximity)
        #expect(proximity.placeName == "Joe's Market Kensington")
        #expect(proximity.distance == places[1].distance(from: here))
        #expect(!proximity.isHere)
    }

    @Test func insideAPlaceItIsHere() throws {
        let nearest = try #require(places.nearest(1, to: here).first?.proximity)
        #expect(nearest.isHere)
        #expect(nearest.distance == 0)
        #expect(nearest.placeName == "Joe's Market Notting Hill")
    }

    /// Inside two places, both are here, and the one whose middle is nearer comes first.
    @Test func betweenPlacesYouAreInsideTheNearerMiddleComesFirst() {
        let wide = CardLocation(name: "Wide", latitude: 51.5100, longitude: -0.1963, radius: 500)  // ~100 m north
        let close = CardLocation(name: "Close", latitude: 51.5093, longitude: -0.1963, radius: 100)  // ~22 m north
        let nearest = [wide, close].nearest(5, to: here)
        #expect(names(nearest) == ["Close", "Wide"])
        #expect(nearest.allSatisfy { $0.proximity?.isHere == true })
    }

    /// Places the same distance away keep the card's order, here or not.
    @Test(arguments: [false, true], [100.0, 2_000.0])
    func equalDistancesKeepTheCardsOrder(reversed: Bool, metresNorth: Double) {
        let latitude = 51.5091 + metresNorth / 111_000
        let first = CardLocation(name: "First", latitude: latitude, longitude: -0.1963)
        let second = CardLocation(name: "Second", latitude: latitude, longitude: -0.1963)
        let order = reversed ? [second, first] : [first, second]
        let nearest = order.nearest(5, to: here)
        #expect(names(nearest) == order.map(\.name))
        #expect(nearest.allSatisfy { $0.proximity?.isHere == (metresNorth < CardLocation.defaultRadius) })
    }

    @Test func theListStopsAtFive() {
        let list = CardPlaces(places, near: here)
        #expect(CardPlaces.limit == 5)
        #expect(list.listed.count == 5)
        #expect(list.unlisted == 2)
        #expect(list.count == 7)
        #expect(names(list.listed) == names(places.nearest(5, to: here)))
    }

    @Test(arguments: 0...7)
    func fewerThanFiveAreAllListed(count: Int) {
        let list = CardPlaces(Array(places.prefix(count)), near: here)
        #expect(list.listed.count == min(count, 5))
        #expect(list.unlisted == max(0, count - 5))
    }

    /// Without a location, the first five in the card's order, with no distances.
    @Test func withoutALocationTheyKeepTheCardsOrder() {
        let list = CardPlaces(places, near: nil)
        #expect(names(list.listed) == places.prefix(5).map(\.name))
        #expect(list.listed.allSatisfy { $0.proximity == nil })
        #expect(list.unlisted == 2)
        #expect(!list.hasDistances)
        #expect(CardPlaces(places, near: here).hasDistances)
    }

    /// One place already shows in the face's top panel, so only two or more are listed.
    @Test(arguments: [(0, false), (1, false), (2, true), (7, true)])
    func onlyMoreThanOnePlaceIsListed(count: Int, isListed: Bool) {
        #expect(CardPlaces(Array(places.prefix(count)), near: here).isListed == isListed)
        #expect(CardPlaces(Array(places.prefix(count)), near: nil).isListed == isListed)
    }

    @Test func noPlacesListNothing() {
        #expect([CardLocation]().nearest(5, to: here).isEmpty)
        #expect(places.nearest(0, to: here).isEmpty)
        #expect(CardPlaces.none.listed.isEmpty)
        #expect(CardPlaces.none.unlisted == 0)
    }

    /// The face's top panel names the same place the list puts first, even inside two.
    @Test func theNearestAgreesWithTheList() throws {
        let wide = CardLocation(name: "Wide", latitude: 51.5100, longitude: -0.1963, radius: 500)
        let close = CardLocation(name: "Close", latitude: 51.5093, longitude: -0.1963, radius: 100)
        let proximity = try #require([wide, close].proximity(to: here))
        #expect(proximity.placeName == "Close")
        #expect(proximity == [wide, close].nearest(1, to: here).first?.proximity)
    }

    @Test func theCardScreenGetsItsPlaces() {
        let item = CardItem(code: "482019375610284", name: "Joe's Market", locations: places)
        let detail = CardDetail(item, near: here)
        #expect(detail.places == CardPlaces(places, near: here))
        #expect(detail.proximity == detail.places.listed.first?.proximity)
        #expect(CardDetail(item, near: nil).places.hasDistances == false)
    }

    @Test func aPlaceOpensInMapsAsAPinWithItsName() throws {
        let url = try #require(places[0].mapsURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "https")
        #expect(components.host == "maps.apple.com")
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        #expect(items["ll"] == "51.509,-0.196")
        #expect(items["q"] == "Joe's Market Notting Hill")
    }
}
