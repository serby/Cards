@testable import Cards
import Foundation
import Testing

struct ChangelogTests {
    private let json = Data("""
    {"versions": [
      {"version": "1.3", "date": null, "changes": [
        {"type": "new", "text": "Pick any colour you like.", "en-US": "Pick any color you like."},
        {"type": "teleport", "text": "A kind from a newer build."},
        {"type": "fixed", "text": "Fixed a crash."}
      ]},
      {"version": "1.1", "date": "2026-01-01", "changes": [{"type": "improved", "text": "Faster scanning."}]}
    ]}
    """.utf8)

    @Test func britishTextUnlessTheRegionIsTheUS() throws {
        let british = try ChangelogStore.decode(json, americanEnglish: false)
        let american = try ChangelogStore.decode(json, americanEnglish: true)
        #expect(british[0].changes[0].text == "Pick any colour you like.")
        #expect(american[0].changes[0].text == "Pick any color you like.")
        #expect(american[0].changes[1].text == "Fixed a crash.")
    }

    @Test func unknownKindsAreLeftOut() throws {
        let versions = try ChangelogStore.decode(json, americanEnglish: false)
        #expect(versions[0].changes.map(\.kind) == [.new, .fixed])
    }

    @Test func datesAreDaysAndNullIsInPreparation() throws {
        let versions = try ChangelogStore.decode(json, americanEnglish: false)
        #expect(versions[0].date == nil)
        let date = try #require(versions[1].date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        #expect(calendar.dateComponents([.year, .month, .day], from: date) == DateComponents(year: 2_026, month: 1, day: 1))
    }

    @Test func missingChangelogIsEmpty() throws {
        let empty = try #require(Bundle(path: FileManager.default.temporaryDirectory.path()))
        #expect(ChangelogStore.bundled(empty).isEmpty)
    }

    /// The release skill adds the new version to changelog.json before the
    /// version is bumped, so What's New always starts with the app's version.
    @Test func bundledChangelogStartsWithTheAppVersion() throws {
        let versions = ChangelogStore.bundled()
        let appVersion = try #require(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        #expect(versions.first?.version == appVersion)
        #expect(versions.allSatisfy { !$0.changes.isEmpty })
    }
}
