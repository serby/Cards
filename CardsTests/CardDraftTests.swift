@testable import Cards
import Foundation
import Testing

/// The form's fields for a card, and saving them back to it (CARD-3, CARD-5, CARD-14).
struct CardDraftTests {
    private let place = CardLocation(name: "Local Roast Portobello", latitude: 51.5150, longitude: -0.2040, radius: 100)
    private let note = "Every tenth coffee is free.\nAsk for a stamp at the till."

    @Test func aCardRoundTripsThroughItsForm() {
        let card = CardItem(
            code: "1234567890128",
            name: "Local Roast Coffee",
            barcodeType: .ean13,
            color: .red,
            locations: [place],
            notifiesOnArrival: false,
            icon: "cup.and.saucer.fill",
            notes: note
        )
        let saved = CardItem(code: "", name: "")
        saved.apply(CardDraft(card))

        #expect(saved.name == card.name)
        #expect(saved.code == card.code)
        #expect(saved.getBarcodeType() == .ean13)
        #expect(saved.getColor() == .red)
        #expect(saved.locations == [place])
        #expect(!saved.notifiesOnArrival)
        #expect(saved.icon == "cup.and.saucer.fill")
        #expect(saved.notes == note)
    }

    @Test func savingTrimsTheNameAndCode() {
        let card = CardItem(code: "", name: "")
        card.apply(CardDraft(name: "  Local Roast Coffee\n", code: " 1234567890128 "))
        #expect(card.name == "Local Roast Coffee")
        #expect(card.code == "1234567890128")
    }

    @Test func aCardWithoutNotesOpensWithAnEmptyNotesField() {
        #expect(CardDraft(CardItem(code: "1234567890128", name: "Local Roast Coffee")).notes.isEmpty)
    }

    @Test func savingTrimsTheNotes() {
        let card = CardItem(code: "", name: "")
        card.apply(CardDraft(name: "Local Roast Coffee", code: "1234567890128", notes: "\n  \(note)  \n\n"))
        #expect(card.notes == note)
    }

    /// Clearing the field, or leaving only spaces and new lines in it, removes the notes.
    @Test(arguments: ["", "  ", "\n\n", " \n \t"])
    func savingBlankNotesRemovesThem(_ typed: String) {
        let card = CardItem(code: "1234567890128", name: "Local Roast Coffee", notes: note)
        var draft = CardDraft(card)
        draft.notes = typed
        card.apply(draft)
        #expect(card.notes == nil)
    }

    /// The card screen shows notes only when there are some (CARD-4, CARD-14).
    @Test func theCardScreenHasNotesOnlyWhenTheCardDoes() {
        let withNotes = CardItem(code: "1234567890128", name: "Local Roast Coffee", notes: note)
        #expect(CardDetail(withNotes, near: nil).notes == note)
        #expect(CardDetail(CardItem(code: "9988776655443", name: "Honeycomb Rewards"), near: nil).notes == nil)
        let blank = CardDetail(id: "1", name: "Local Roast Coffee", code: "1", barcodeType: .ean13, timestamp: .now, notes: " \n ")
        #expect(blank.notes == nil)
    }
}
