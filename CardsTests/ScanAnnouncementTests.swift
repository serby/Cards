@testable import Cards
import Foundation
import Testing

/// After a scan VoiceOver says what was read, with the code spelled out
/// character by character rather than read as a number.
@MainActor
struct ScanAnnouncementTests {
    @Test func namesTheFormatAndSpellsOutTheCode() throws {
        let message = CardEditScreen.scanAnnouncement(code: "5012345678900", type: .ean13)
        #expect(String(message.characters) == "Scanned EAN-13: 5012345678900")
        let spelled = message.runs.filter { $0.accessibilitySpeechSpellsOutCharacters == true }
        #expect(spelled.map { String(message[$0.range].characters) } == ["5012345678900"])
    }

    /// QR Code and Code 128 already end or start in "Code", so the message
    /// never says it twice.
    @Test(arguments: [BarcodeType.qrCode, .code128, .code39, .code93])
    func neverSaysCodeTwice(type: BarcodeType) {
        let message = String(CardEditScreen.scanAnnouncement(code: "ABC-123", type: type).characters)
        #expect(message == "Scanned \(type.rawValue): ABC-123")
        #expect(!message.localizedCaseInsensitiveContains("code code"))
    }

    @Test func leavesOutAFormatItCannotName() {
        let message = CardEditScreen.scanAnnouncement(code: "ABC-123", type: nil)
        #expect(String(message.characters) == "Scanned code ABC-123")
        let spelled = message.runs.filter { $0.accessibilitySpeechSpellsOutCharacters == true }
        #expect(spelled.map { String(message[$0.range].characters) } == ["ABC-123"])
    }
}
