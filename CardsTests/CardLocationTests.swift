@testable import Cards
import CoreLocation
import Foundation
import SwiftData
import Testing

struct CardLocationTests {
    private let westway = CardLocation(name: "Westway", latitude: 51.5203, longitude: -0.2094, radius: 150)

    @Test func distanceIsZeroInsideTheCircle() {
        let inside = CLLocation(latitude: 51.5205, longitude: -0.2094)  // ~22 m from the centre
        #expect(westway.distance(from: inside) == 0)
    }

    @Test func distanceIsMeasuredToTheEdge() {
        let centre = CLLocation(latitude: westway.latitude, longitude: westway.longitude)
        let outside = CLLocation(latitude: 51.5303, longitude: -0.2094)  // ~1.1 km north
        let toCentre = outside.distance(from: centre)
        #expect(abs(westway.distance(from: outside) - (toCentre - 150)) < 0.001)
    }

    @Test func proximityPicksTheNearestLocation() throws {
        let far = CardLocation(name: "Wembley", latitude: 51.5560, longitude: -0.2796)
        let here = CLLocation(latitude: 51.5210, longitude: -0.2094)
        let proximity = try #require([far, westway].proximity(to: here))
        #expect(proximity.placeName == "Westway")
    }

    @Test func proximityNeedsALocationAndPlaces() {
        #expect([westway].proximity(to: nil) == nil)
        #expect([CardLocation]().proximity(to: CLLocation(latitude: 51.5, longitude: 0)) == nil)
    }

    @Test func proximityIsHereInsideTheCircle() throws {
        let proximity = try #require([westway].proximity(to: CLLocation(latitude: 51.5203, longitude: -0.2094)))
        #expect(proximity.isHere)
    }

    @Test @MainActor func locationsPersistThroughSwiftData() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: CardItem.self, configurations: configuration)
        container.mainContext.insert(CardItem(code: "42", name: "Costa", locations: [westway]))
        try container.mainContext.save()

        let fetched = try ModelContext(container).fetch(FetchDescriptor<CardItem>())
        #expect(fetched.first?.locations == [westway])
    }

    @Test func exportRoundTripKeepsLocations() throws {
        let original = CardItem(code: "42", name: "Costa", locations: [westway])
        let data = try JSONEncoder().encode([CardItemDTO(from: original)])
        let imported = try JSONDecoder().decode([CardItemDTO].self, from: data)
        #expect(imported.first?.toCardItem().locations == [westway])
    }

    @Test func exportWithoutLocationsImportsWithNone() throws {
        let legacy = #"[{"code":"42","name":"Costa","order":0,"timestamp":0,"type":"EAN-13"}]"#
        let imported = try JSONDecoder().decode([CardItemDTO].self, from: Data(legacy.utf8))
        #expect(imported.first?.toCardItem().locations.isEmpty == true)
    }
}

@MainActor
struct ArrivalNotifierTests {
    private func card(_ name: String, _ locations: [CardLocation]) -> ArrivalNotifier.Card {
        ArrivalNotifier.Card(name: name, code: name, barcodeType: .code128, locations: locations)
    }

    private func place(_ name: String, latitude: Double) -> CardLocation {
        CardLocation(name: name, latitude: latitude, longitude: 0)
    }

    @Test func cardsWithoutLocationsAreNotWatched() {
        #expect(ArrivalNotifier.plan([card("Nectar", [])], near: nil).isEmpty)
    }

    @Test func everyLocationOfEveryCardIsWatched() {
        let cards = [
            card("Costa", [place("A", latitude: 51), place("B", latitude: 52)]),
            card("Boots", [place("C", latitude: 53)])
        ]
        let names = ArrivalNotifier.plan(cards, near: nil).map(\.location.name)
        #expect(names == ["A", "B", "C"])
    }

    @Test func nearestLocationsAreKeptWithinTheRegionLimit() {
        let places = (0..<30).map { place("P\($0)", latitude: 50 + Double($0) * 0.01) }
        let here = CLLocation(latitude: 50.295, longitude: 0)  // just north of P29, the furthest place from P0
        let plan = ArrivalNotifier.plan([card("Costa", places)], near: here)
        #expect(plan.count == ArrivalNotifier.regionLimit)
        #expect(plan.first?.location.name == "P29")
        #expect(!plan.contains { $0.location.name == "P0" })
    }
}
