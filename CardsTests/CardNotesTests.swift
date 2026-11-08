@testable import Cards
import Foundation
import SwiftData
import Testing

/// A card's notes: kept trimmed, blank notes are none, and they sync, export
/// and import with the card (CARD-14, DATA-1, DATA-2, DATA-4).
struct CardNotesTests {
    private let note = "Points reset each January.\nAsk for a paper receipt."

    @Test(arguments: [nil, "", " ", "\n", " \n\t \n"])
    func blankNotesAreNone(_ text: String?) {
        #expect(CardNotes.kept(text) == nil)
    }

    @Test func notesAreTrimmedAtEitherEndOnly() {
        #expect(CardNotes.kept("  \n\(note)\n  ") == note)
    }

    @Test func aCardHasNoNotesUntilItIsGivenSome() {
        #expect(CardItem(code: "9988776655443", name: "Honeycomb Rewards").notes == nil)
        #expect(CardItem(code: "9988776655443", name: "Honeycomb Rewards", notes: " \n ").notes == nil)
        #expect(CardItem(code: "9988776655443", name: "Honeycomb Rewards", notes: " \(note) ").notes == note)
    }

    @Test @MainActor func notesPersistThroughSwiftData() throws {
        let container = try ModelContainer(for: CardStore.schema, configurations: [CardStore.configuration(inMemory: true)])
        container.mainContext.insert(CardItem(code: "9988776655443", name: "Honeycomb Rewards", notes: note))
        try container.mainContext.save()

        let fetched = try ModelContext(container).fetch(FetchDescriptor<CardItem>())
        #expect(fetched.first?.notes == note)
    }

    @Test func exportRoundTripKeepsNotes() throws {
        let original = CardItem(code: "9988776655443", name: "Honeycomb Rewards", notes: note)
        let data = try JSONEncoder().encode([CardItemDTO(from: original)])
        let imported = try JSONDecoder().decode([CardItemDTO].self, from: data)
        #expect(imported.first?.toCardItem().notes == note)
    }

    /// A card without notes exports no `notes` key, as before notes existed.
    @Test func aCardWithoutNotesExportsNone() throws {
        let data = try JSONEncoder().encode(CardItemDTO(from: CardItem(code: "9988776655443", name: "Honeycomb Rewards")))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["notes"] == nil)
    }

    @Test func anExportFromBeforeNotesImportsWithNone() throws {
        let legacy = """
        [{"code":"42","name":"Local Roast Coffee","order":0,"timestamp":"2026-01-01T09:41:00Z","type":"EAN-13","color":"red"}]
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode([CardItemDTO].self, from: Data(legacy.utf8))
        let card = try #require(imported.first?.toCardItem())
        #expect(card.notes == nil)
        #expect(card.name == "Local Roast Coffee")
    }

    @Test func blankNotesInAnExportImportAsNone() throws {
        let file = Data(#"[{"code":"42","name":"Local Roast Coffee","notes":"  \n "}]"#.utf8)
        let imported = try JSONDecoder().decode([CardItemDTO].self, from: file)
        let result = CardImport.cards(from: imported, existing: [])
        #expect(result.added.count == 1)
        #expect(result.added.first?.notes == nil)
    }
}
