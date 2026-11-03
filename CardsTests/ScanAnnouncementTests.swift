@testable import Cards
import Foundation
import Testing

/// After a scan VoiceOver says what was read, with the code spelled out
/// character by character rather than read as a number.
@MainActor
struct ScanAnnouncementTests {
    @Test func namesTheFormatAndSpellsOutTheCode() throws {
        let message = CardEditScreen.scanAnnouncement(code: "5012345678900", type: .ean13)
        #expect(String(message.characters) == "Scanned EAN-13 code 5012345678900")
        let spelled = message.runs.filter { $0.accessibilitySpeechSpellsOutCharacters == true }
        #expect(spelled.map { String(message[$0.range].characters) } == ["5012345678900"])
    }

    @Test func leavesOutAFormatItCannotName() {
        let message = CardEditScreen.scanAnnouncement(code: "ABC-123", type: nil)
        #expect(String(message.characters) == "Scanned code ABC-123")
        let spelled = message.runs.filter { $0.accessibilitySpeechSpellsOutCharacters == true }
        #expect(spelled.map { String(message[$0.range].characters) } == ["ABC-123"])
    }
}
