@testable import Cards
import CloudKit
import Foundation
import Testing

/// iCloud Sync's deletion (DATA-9) and the acknowledged software (PLAT-12).
@MainActor
struct PrivacySettingsTests {
    @Test func deletingFromICloudSaysHowItWent() async {
        #expect(await SettingsScreen.deletion(by: ICloudCards(deleteAll: {})) == .deleted)
        #expect(await SettingsScreen.deletion(by: ICloudCards(deleteAll: { throw CKError(.networkUnavailable) })) == .failed)
        #expect(await SettingsScreen.deletion(by: ICloudCards(deleteAll: { throw CKError(.notAuthenticated) })) == .failed)
    }

    /// No cards in iCloud, as on a device that never synced, is deleted already.
    @Test func nothingInICloudIsNotAFailure() {
        #expect(ICloudCards.isNothingToDelete(CKError(.zoneNotFound)))
        #expect(ICloudCards.isNothingToDelete(CKError(.userDeletedZone)))
        #expect(!ICloudCards.isNothingToDelete(CKError(.notAuthenticated)))
        #expect(!ICloudCards.isNothingToDelete(CKError(.networkFailure)))
    }

    /// Each step of a deletion has its own caption, so the screen always says
    /// where it has got to.
    @Test func everyDeletionStepHasItsOwnCaption() {
        let captions = ICloudDeletion.allCases.map { String(localized: SettingsListView.iCloudDeletionCaption($0)) }
        #expect(Set(captions).count == ICloudDeletion.allCases.count)
    }

    /// Every package the project resolves is acknowledged, so adding one (such
    /// as a crash reporter) without its licence fails here.
    @Test func everyPackageIsAcknowledged() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appending(path: "Cards.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"))
        let acknowledged = Set(OpenSourceLibrary.all.compactMap { $0.url?.absoluteString })
        for pin in try JSONDecoder().decode(ResolvedPackages.self, from: data).pins {
            let url = pin.location.hasSuffix(".git") ? String(pin.location.dropLast(4)) : pin.location
            #expect(acknowledged.contains(url), "\(url) is in Package.resolved but not in OpenSourceLibrary.all")
        }
    }

    @Test func everyLicenceIsShownInFull() {
        for library in OpenSourceLibrary.all {
            #expect(library.licenceText.contains("Copyright"), "\(library.name)'s licence has no copyright line")
            #expect(library.licenceText.contains("THE SOFTWARE IS PROVIDED \"AS IS\""), "\(library.name)'s licence is cut short")
        }
    }
}

/// The pins in Package.resolved, as far as the acknowledgements need them.
private struct ResolvedPackages: Decodable {
    struct Pin: Decodable { let location: String }
    let pins: [Pin]
}
