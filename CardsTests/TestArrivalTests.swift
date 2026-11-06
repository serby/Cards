@testable import Cards
import Foundation
import Testing

/// The Development tab's test notification (DEV-2) is the card's real arrival
/// alert, under an identifier of its own.
struct TestArrivalTests {
    private let boulderBarn = CardLocation(name: "Boulder Barn", latitude: 51.5203, longitude: -0.2094, radius: 150)
    private let wembley = CardLocation(name: "Nordic Nest Wembley", latitude: 51.5560, longitude: -0.2796, radius: 400)

    private func card(_ locations: [CardLocation]) -> ArrivalPlan.Card {
        ArrivalPlan.Card(name: "Climbing", code: "climb-42", barcodeType: .code128, locations: locations)
    }

    @Test func saysWhatArrivingAtTheFirstPlaceSays() {
        let real = ArrivalPlan.alert(for: ArrivalPlan.Arrival(card: card([boulderBarn, wembley]), location: boulderBarn))
        let test = TestArrival.alert(for: card([boulderBarn, wembley]))
        #expect(test.title == real.title)
        #expect(test.body == real.body)
        #expect(test.body == "You're at Boulder Barn. Your barcode is ready.")
        #expect(test.code == real.code)
        #expect(test.place == boulderBarn)
        #expect(test.barcodePNG != nil)
    }

    @Test func aCardWithNoPlacesIsAtTest() {
        let test = TestArrival.alert(for: card([]))
        #expect(test.title == "Climbing")
        #expect(test.body == "You're at Test. Your barcode is ready.")
        #expect(test.place.name == TestArrival.placeholderName)
    }

    @Test func neverReplacesTheArrivalScheduledAtThePlace() {
        let real = ArrivalPlan.alert(for: ArrivalPlan.Arrival(card: card([boulderBarn]), location: boulderBarn))
        let first = TestArrival.alert(for: card([boulderBarn]))
        let second = TestArrival.alert(for: card([boulderBarn]))
        #expect(first.id != real.id)
        #expect(first.id != second.id)
        #expect(first.id.hasPrefix("test."))
    }
}
