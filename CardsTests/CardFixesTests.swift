@testable import Cards
import CoreLocation
import Foundation
import Testing

/// The rules behind the November 2026 fixes: saving, ordering, importing,
/// arrival choices and opening cards from outside the Cards tab.
struct CardFixesTests {
    @Test func aCardNeedsANameAndACodeOfItsOwn() {
        #expect(CardDraft(name: "Gym", code: "123").canSave(takenCodes: []))
        #expect(!CardDraft(name: "  ", code: "123").canSave(takenCodes: []))
        #expect(!CardDraft(name: "Gym", code: "").canSave(takenCodes: []))
        #expect(!CardDraft(name: "Gym", code: " 123 ").canSave(takenCodes: ["123"]))
        #expect(CardDraft(name: " Gym ", code: " 123 ").trimmedCode == "123")
    }

    @Test func newCardsGoAtTheEnd() {
        let cards = [CardItem(code: "a", name: "A", order: 0), CardItem(code: "b", name: "B", order: 4)]
        #expect(CardItem.nextOrder(after: cards) == 5)
        #expect(CardItem.nextOrder(after: []) == 0)
    }

    @Test func importSkipsCardsAlreadyThereAndAppendsInExportedOrder() {
        let existing = [CardItem(code: "111", name: "Gym", order: 0), CardItem(code: "222", name: "Library", order: 1)]
        let exported = [
            CardItemDTO(from: CardItem(code: "222", name: "Library", order: 7)),
            CardItemDTO(from: CardItem(code: "333", name: "Pool", order: 3)),
            CardItemDTO(from: CardItem(code: "333", name: "Pool again", order: 4)),
            CardItemDTO(from: CardItem(code: "444", name: "Cafe", order: 0)),
            CardItemDTO(from: CardItem(code: " 555 ", name: " Bakery ", order: 5)),
            CardItemDTO(from: CardItem(code: "666", name: "  ", order: 6)),
            CardItemDTO(from: CardItem(code: " 111", name: "Gym again", order: 8))
        ]
        let result = CardImport.cards(from: exported, existing: existing)
        #expect(result.added.map(\.code) == ["444", "333", "555"])
        #expect(result.added.map(\.name) == ["Cafe", "Pool", "Bakery"])
        #expect(result.added.map(\.order) == [2, 3, 4])
        #expect(result.alreadyHere == 2)
        #expect(result.repeated == 1)
        #expect(result.incomplete == 1)
    }

    @Test func importKeepsFileOrderWithoutAnExportedOrder() throws {
        let file = Data(#"[{"code": "b", "name": "B"}, {"code": "a", "name": "A", "order": 0}, {"code": "c", "name": "C"}]"#.utf8)
        let dtos = try JSONDecoder().decode([CardItemDTO].self, from: file)
        let added = CardImport.cards(from: dtos, existing: []).added
        #expect(added.map(\.code) == ["a", "b", "c"])
        #expect(added.allSatisfy { $0.getBarcodeType() == .code128 })
    }

    /// Each count takes the catalogue's English plural forms, so one card is
    /// never "1 cards". An export with no cards in it is valid JSON, so the
    /// import works, but "Imported 0 cards" would read as though it had not.
    @Test func importSummaryCountsProperly() {
        func summary(added: Int, alreadyHere: Int = 0, repeated: Int = 0, incomplete: Int = 0) -> String {
            let cards = (0..<added).map { CardItem(code: "\($0)", name: "Card") }
            let result = CardImport.Result(added: cards, alreadyHere: alreadyHere, repeated: repeated, incomplete: incomplete)
            return CardImport.summary(result, locale: Locale(identifier: "en_GB"))
        }
        #expect(summary(added: 0) == "No cards imported.")
        #expect(summary(added: 1) == "Imported 1 card.")
        #expect(summary(added: 3, alreadyHere: 1) == "Imported 3 cards. 1 was already in Card Barcodes.")
        #expect(summary(added: 0, alreadyHere: 2) == "No cards imported. 2 were already in Card Barcodes.")
        #expect(
            summary(added: 2, alreadyHere: 1, repeated: 2, incomplete: 1)
                == "Imported 2 cards. 1 was already in Card Barcodes. 2 were in the file more than once. 1 was missing a name or code."
        )
        #expect(
            summary(added: 0, repeated: 1, incomplete: 3)
                == "No cards imported. 1 was in the file more than once. 3 were missing a name or code."
        )
    }

    @Test func notifyingIsKeptAndOlderExportsNotify() throws {
        let card = CardItem(code: "1", name: "Gym", notifiesOnArrival: false)
        let data = try JSONEncoder().encode(CardItemDTO(from: card))
        #expect(try JSONDecoder().decode(CardItemDTO.self, from: data).toCardItem().notifiesOnArrival == false)
        let older = Data(#"{"timestamp": 0, "code": "1", "name": "Gym", "order": 0, "type": "Code 128"}"#.utf8)
        #expect(try JSONDecoder().decode(CardItemDTO.self, from: older).toCardItem().notifiesOnArrival)
    }

    @Test func iconAndLastViewedAreKeptAndOlderExportsHaveNone() throws {
        let viewed = Date(timeIntervalSince1970: 1_780_000_000)
        let card = CardItem(code: "1", name: "Gym", icon: "dumbbell", lastViewed: viewed)
        let data = try JSONEncoder().encode(CardItemDTO(from: card))
        let imported = try JSONDecoder().decode(CardItemDTO.self, from: data).toCardItem()
        #expect(imported.icon == "dumbbell")
        #expect(imported.lastViewed == viewed)
        let older = Data(#"{"code": "1", "name": "Gym"}"#.utf8)
        let legacy = try JSONDecoder().decode(CardItemDTO.self, from: older).toCardItem()
        #expect(legacy.icon == nil)
        #expect(legacy.lastViewed == nil)
    }

    @Test @MainActor func cardsSwitchedOffAreNotWatched() {
        let place = CardLocation(name: "Boulder Barn", latitude: 51.52, longitude: -0.209)
        let on = ArrivalPlan.Card(name: "Gym", code: "1", barcodeType: .code128, locations: [place])
        let off = ArrivalPlan.Card(name: "Pool", code: "2", barcodeType: .code128, locations: [place], notifies: false)
        #expect(ArrivalPlan.arrivals(for: [on, off], near: nil).map(\.card.code) == ["1"])
    }

    @Test @MainActor func theNearestPlacesAreWatchedOnceThereIsALocation() {
        let near = CardLocation(name: "Near", latitude: 51.5, longitude: -0.1)
        let far = (0..<ArrivalPlan.regionLimit).map { CardLocation(name: "Far \($0)", latitude: 55, longitude: Double($0)) }
        let card = ArrivalPlan.Card(name: "Gym", code: "1", barcodeType: .code128, locations: far + [near])
        #expect(!ArrivalPlan.arrivals(for: [card], near: nil).map(\.location.name).contains("Near"))
        #expect(ArrivalPlan.arrivals(for: [card], near: CLLocation(latitude: 51.5, longitude: -0.1)).first?.location.name == "Near")
    }

    @Test @MainActor func movingAboutAKilometreChangesTheArea() {
        let here = CLLocation(latitude: 51.5091, longitude: -0.1963)
        #expect(ArrivalPlan.area(of: here) == ArrivalPlan.area(of: CLLocation(latitude: 51.5094, longitude: -0.1960)))
        #expect(ArrivalPlan.area(of: here) != ArrivalPlan.area(of: CLLocation(latitude: 51.5191, longitude: -0.1963)))
        #expect(ArrivalPlan.area(of: nil) == nil)
    }

    @Test func openingACardBringsTheCardsTabForward() {
        let navigation = NavigationManager()
        navigation.tab = .settings
        navigation.navigate(to: .card("123"))
        #expect(navigation.tab == .cards)
    }
}
