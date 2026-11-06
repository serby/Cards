@testable import Cards
import CoreLocation
import Foundation
import Synchronization
import Testing

struct WidgetTests {
    private let westway = CardLocation(name: "Westway", latitude: 51.5203, longitude: -0.2094, radius: 150)
    private let wembley = CardLocation(name: "IKEA Wembley", latitude: 51.5560, longitude: -0.2796, radius: 400)
    private let nearWestway = CLLocation(latitude: 51.5210, longitude: -0.2094)

    private func card(_ name: String, _ locations: [CardLocation] = []) -> WidgetCard {
        WidgetCard(code: name.lowercased(), name: name, barcodeType: .code128, color: .blue, locations: locations)
    }

    @Test func nearestPicksTheCardWithTheClosestLocation() {
        let cards = [card("Library"), card("IKEA", [wembley]), card("Climbing", [westway])]
        #expect(cards.nearest(to: nearWestway)?.name == "Climbing")
    }

    @Test func nearestFallsBackToTheFirstCardWithoutALocation() {
        let cards = [card("Library"), card("Climbing", [westway])]
        #expect(cards.nearest(to: nil)?.name == "Library")
    }

    @Test func nearestFallsBackToTheFirstCardWhenNoneHaveLocations() {
        #expect([card("Library"), card("Gym")].nearest(to: nearWestway)?.name == "Library")
        #expect([WidgetCard]().nearest(to: nearWestway) == nil)
    }

    @Test func stateCarriesTheDistanceToTheNearestLocation() throws {
        let state = card("Climbing", [wembley, westway]).state(near: nearWestway)
        let proximity = try #require(state.proximity)
        #expect(proximity.placeName == "Westway")
        #expect(state.code == "climbing")
        #expect(state.color == .blue)
    }

    @Test func widgetCardCopiesWhatTheWidgetNeeds() {
        let item = CardItem(code: "123", name: "Gym", barcodeType: .qrCode, color: .teal, locations: [westway])
        #expect(WidgetCard(item) == WidgetCard(code: "123", name: "Gym", barcodeType: .qrCode, color: .teal, locations: [westway]))
    }

    @Test func snapshotRoundTripsAndSkipsUnchangedWrites() {
        let url = FileManager.default.temporaryDirectory.appending(path: "widget-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let reloads = Count()
        let snapshot = WidgetSnapshot.file(at: url, onChange: { reloads.increment() })
        let cards = [card("Climbing", [westway]), card("Library")]

        #expect(snapshot.read().isEmpty)
        snapshot.write(cards)
        #expect(snapshot.read() == cards)
        #expect(reloads.value == 1)
        snapshot.write(cards)
        #expect(reloads.value == 1)
        snapshot.write(Array(cards.reversed()))
        #expect(reloads.value == 2)
        #expect(snapshot.read() == Array(cards.reversed()))
    }

    @Test func snapshotThatCannotBeReadIsEmpty() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "widget-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        #expect(WidgetSnapshot.file(at: url).read().isEmpty)
    }

    @Test func snapshotWithoutAnAppGroupReadsAndWritesNothing() {
        let reloads = Count()
        let snapshot = WidgetSnapshot.file(at: nil, onChange: { reloads.increment() })
        snapshot.write([card("Library")])
        #expect(snapshot.read().isEmpty)
        #expect(reloads.value == 0)
    }
}

/// Counts calls from any thread, for clients whose closures are `@Sendable`.
private final class Count: Sendable {
    private let calls = Mutex(0)

    var value: Int { calls.withLock { $0 } }

    func increment() {
        calls.withLock { $0 += 1 }
    }
}
