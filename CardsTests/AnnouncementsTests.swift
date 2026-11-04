@testable import Cards
import Foundation
import Testing

/// What VoiceOver hears after an action that changes the screen without
/// moving focus to the result.
struct AnnouncementsTests {
    /// One card by name, several by how many; and places in strings of their
    /// own, so a translation can agree with the word for each.
    @Test func deletingNamesOneAndCountsSeveral() {
        #expect(Announcements.deletedCards(["Tesco Clubcard"]) == "Deleted card Tesco Clubcard")
        #expect(Announcements.deletedCards(["Tesco Clubcard", "Boots Advantage"]) == "Deleted 2 cards")
        #expect(Announcements.deletedCards(["A", "B", "C", "D", "E"]) == "Deleted 5 cards")
        #expect(Announcements.deletedPlaces(["Westway"]) == "Deleted place Westway")
        #expect(Announcements.deletedPlaces(["Westway", "The Castle"]) == "Deleted 2 places")
    }

    @Test func addingAPlaceIsNotCutOffByTheSheetClosing() {
        let message = Announcements.added("Westway")
        #expect(String(message.characters) == "Added Westway")
        #expect(message.runs.allSatisfy { $0.accessibilitySpeechAnnouncementPriority == .high })
    }
}
