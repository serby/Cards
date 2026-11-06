@testable import Cards
import Foundation
import Testing

/// What VoiceOver hears after an action that changes the screen without
/// moving focus to the result.
struct AnnouncementsTests {
    /// One card by name, several by how many; and places in strings of their
    /// own, so a translation can agree with the word for each.
    @Test func deletingNamesOneAndCountsSeveral() {
        #expect(Announcements.deletedCards(["Joe's Market"]) == "Deleted card Joe's Market")
        #expect(Announcements.deletedCards(["Joe's Market", "Green Leaf Pharmacy"]) == "Deleted 2 cards")
        #expect(Announcements.deletedCards(["A", "B", "C", "D", "E"]) == "Deleted 5 cards")
        #expect(Announcements.deletedPlaces(["Boulder Barn"]) == "Deleted place Boulder Barn")
        #expect(Announcements.deletedPlaces(["Boulder Barn", "Local Roast Portobello"]) == "Deleted 2 places")
    }

    @Test func addingAPlaceIsNotCutOffByTheSheetClosing() {
        let message = Announcements.added("Boulder Barn")
        #expect(String(message.characters) == "Added Boulder Barn")
        #expect(message.runs.allSatisfy { $0.accessibilitySpeechAnnouncementPriority == .high })
    }
}
