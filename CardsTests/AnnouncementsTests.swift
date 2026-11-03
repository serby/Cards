@testable import Cards
import Foundation
import Testing

/// What VoiceOver hears after an action that changes the screen without
/// moving focus to the result.
struct AnnouncementsTests {
    @Test func deletingNamesWhatWent() {
        #expect(Announcements.deleted(["Tesco Clubcard"]) == "Deleted Tesco Clubcard")
        #expect(Announcements.deleted(["Tesco Clubcard", "Boots Advantage"]) == "Deleted Tesco Clubcard and Boots Advantage")
    }

    @Test func addingAPlaceIsNotCutOffByTheSheetClosing() {
        let message = Announcements.added("Westway")
        #expect(String(message.characters) == "Added Westway")
        #expect(message.runs.allSatisfy { $0.accessibilitySpeechAnnouncementPriority == .high })
    }
}
