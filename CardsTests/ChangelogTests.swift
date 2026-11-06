@testable import Cards
import Foundation
import Testing

struct ChangelogTests {
    private let json = Data("""
    {"versions": [
      {"version": "1.3", "date": null, "changes": [
        {"type": "new", "text": "Pick any colour you like.", "en-US": "Pick any color you like.",
         "es": "Elige el color que quieras.", "es-MX": "Escoge el color que quieras.", "de": "Wähle eine beliebige Farbe.", "ja": "好きなカラーを選べます。"},
        {"type": "teleport", "text": "A kind from a newer build."},
        {"type": "fixed", "text": "Fixed a crash."}
      ]},
      {"version": "1.1", "date": "2026-01-01", "changes": [{"type": "improved", "text": "Faster scanning."}]}
    ]}
    """.utf8)

    private static let british = ChangelogStore.textKeys(language: "en", region: "GB")

    @Test func britishTextUnlessTheRegionIsTheUS() throws {
        let british = try ChangelogStore.decode(json, textKeys: Self.british)
        let american = try ChangelogStore.decode(json, textKeys: ChangelogStore.textKeys(language: "en", region: "US"))
        #expect(british[0].changes[0].text == "Pick any colour you like.")
        #expect(american[0].changes[0].text == "Pick any color you like.")
        #expect(american[0].changes[1].text == "Fixed a crash.")
    }

    /// A translation for the language and region comes first, then one for the
    /// language; a change with neither, as older versions may be, reads in
    /// British English.
    @Test func translationsForTheAppLanguageAndRegion() throws {
        func first(_ language: String, _ region: String?) throws -> [String] {
            let versions = try ChangelogStore.decode(json, textKeys: ChangelogStore.textKeys(language: language, region: region))
            return [versions[0].changes[0].text, versions[1].changes[0].text]
        }
        #expect(try first("es", "ES") == ["Elige el color que quieras.", "Faster scanning."])
        #expect(try first("es", "MX") == ["Escoge el color que quieras.", "Faster scanning."])
        #expect(try first("es", nil) == ["Elige el color que quieras.", "Faster scanning."])
        #expect(try first("de", "AT") == ["Wähle eine beliebige Farbe.", "Faster scanning."])
        #expect(try first("ja", "JP") == ["好きなカラーを選べます。", "Faster scanning."])
        #expect(try first("fr", "FR") == ["Pick any colour you like.", "Faster scanning."])
    }

    @Test func unknownKindsAreLeftOut() throws {
        let versions = try ChangelogStore.decode(json, textKeys: Self.british)
        #expect(versions[0].changes.map(\.kind) == [.new, .fixed])
    }

    @Test func datesAreDaysAndNullIsInPreparation() throws {
        let versions = try ChangelogStore.decode(json, textKeys: Self.british)
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
