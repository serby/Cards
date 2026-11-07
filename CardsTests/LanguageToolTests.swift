@testable import Cards
import Foundation
import Testing

/// The Development tab's Language tool (DEV-4): what it offers, which choice is
/// ticked, and that choosing one sets or clears the app's override and then quits.
@MainActor
struct LanguageToolTests {
    private let shipped = [StoryLanguage("en"), StoryLanguage("de"), StoryLanguage("ja"), StoryLanguage("es")]

    // MARK: Choices

    @Test func systemComesFirstThenEveryLanguage() {
        #expect(LanguageChoice.all(shipped).map(\.id) == ["system", "en", "de", "ja", "es"])
    }

    @Test func theAppBundleOffersSystemAndTheLanguagesItShips() {
        let ids = LanguageChoice.all().map(\.id)
        #expect(ids.first == "system")
        #expect(Set(["en", "de", "es", "ja"]).isSubset(of: ids))
        #expect(!ids.contains("Base"))
    }

    /// Each language is named in itself, with its English name under it.
    @Test(arguments: [
        ("de", ["Deutsch", "German"]),
        ("ja", ["日本語", "Japanese"]),
        ("es", ["Español", "Spanish"])
    ])
    func languagesAreNamedInThemselves(_ id: String, _ names: [String]) {
        let choice = LanguageChoice(language: StoryLanguage(id))
        #expect(choice.name == names.first)
        #expect(choice.detail == names.last)
        #expect(choice.override == [id])
    }

    /// English's two names are the same, so it has no line under its name.
    @Test func englishIsNamedOnce() {
        let choice = LanguageChoice(language: StoryLanguage("en"))
        #expect(choice.name == "English")
        #expect(choice.detail == nil)
        #expect(choice.override == ["en"])
    }

    @Test func systemHasNoOverride() {
        #expect(LanguageChoice.system.name == "System")
        #expect(LanguageChoice.system.detail == "The iPhone's language")
        #expect(LanguageChoice.system.override.isEmpty)
    }

    @Test func theConfirmationSaysWhereTheAppOpens() {
        let german = LanguageChoice(language: StoryLanguage("de"))
        #expect(german.confirmationTitle == "Open in Deutsch?")
        #expect(german.confirmationMessage == "Card Barcodes closes so it can open in Deutsch. Open it again from the Home Screen.")
        #expect(LanguageChoice.system.confirmationTitle == "Open in the iPhone's Language?")
        #expect(
            LanguageChoice.system.confirmationMessage
                == "Card Barcodes closes so it can open in the iPhone's language. Open it again from the Home Screen."
        )
    }

    // MARK: Current

    @Test func noOverrideTicksSystem() {
        #expect(LanguageChoice.current(for: [], in: LanguageChoice.all(shipped)) == .system)
    }

    /// Matched as iOS matches an app's languages, so an override with a region,
    /// or a list, ticks the language the app opens in.
    @Test(arguments: [
        (["de"], "de"),
        (["de-GB"], "de"),
        (["ja-JP", "en"], "ja"),
        (["fr", "es"], "es"),
        // A language the app does not have opens it in its development language.
        (["fr"], "en")
    ])
    func anOverrideTicksTheLanguageTheAppOpensIn(_ override: [String], _ id: String) {
        #expect(LanguageChoice.current(for: override, in: LanguageChoice.all(shipped)).id == id)
    }

    // MARK: Choosing

    @Test(arguments: [nil, "de"] as [String?])
    func choosingSetsTheOverrideThenQuits(_ id: String?) {
        let events = Events()
        let client = AppLanguageClient(
            override: { [] },
            setOverride: { events.list.append("set \($0)") },
            quit: { events.list.append("quit") }
        )
        client.open(in: LanguageChoice(language: id.map(StoryLanguage.init)))
        #expect(events.list == ["set \(id.map { [$0] } ?? [])", "quit"])
    }

    private func withDefaults(_ body: (UserDefaults, String) throws -> Void) throws {
        let name = "CardsTests.Language.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults, name)
    }

    @Test func aLanguageIsSavedAsTheAppLanguagesDefault() throws {
        try withDefaults { defaults, domain in
            let events = Events()
            let client = AppLanguageClient.defaults(suiteName: domain, domain: domain, quit: { events.list.append("quit") })
            #expect(client.override().isEmpty)

            client.open(in: LanguageChoice(language: StoryLanguage("de")))
            #expect(defaults.persistentDomain(forName: domain)?["AppleLanguages"] as? [String] == ["de"])
            #expect(client.override() == ["de"])
            #expect(events.list == ["quit"])
        }
    }

    @Test func systemClearsTheOverride() throws {
        try withDefaults { defaults, domain in
            defaults.set(["ja"], forKey: "AppleLanguages")
            let events = Events()
            let client = AppLanguageClient.defaults(suiteName: domain, domain: domain, quit: { events.list.append("quit") })
            #expect(client.override() == ["ja"])

            client.open(in: .system)
            #expect(defaults.persistentDomain(forName: domain)?["AppleLanguages"] == nil)
            #expect(client.override().isEmpty)
            #expect(LanguageChoice.current(for: client.override(), in: LanguageChoice.all(shipped)) == .system)
            #expect(events.list == ["quit"])
        }
    }

    /// The region is the iPhone's, so choosing a language writes nothing else.
    @Test func choosingALanguageLeavesTheRegionAlone() throws {
        try withDefaults { defaults, domain in
            AppLanguageClient.defaults(suiteName: domain, domain: domain, quit: {})
                .open(in: LanguageChoice(language: StoryLanguage("de")))
            let keys = defaults.persistentDomain(forName: domain)?.keys.sorted() ?? []
            #expect(keys == ["AppleLanguages"])
        }
    }
}

/// What a stand-in client was asked to do, in order.
@MainActor
private final class Events {
    var list: [String] = []
}
