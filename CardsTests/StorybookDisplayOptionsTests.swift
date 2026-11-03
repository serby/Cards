@testable import Cards
import Foundation
import SwiftUI
import Testing

/// The Storybook's language and direction options: which languages it offers,
/// what Automatic resolves to, and that both survive a relaunch.
@MainActor
struct StorybookDisplayOptionsTests {
    private func ids(_ languages: [StoryLanguage]) -> [String] {
        languages.map(\.id)
    }

    // MARK: Languages

    @Test func languagesLeaveOutBase() {
        let languages = StoryLanguage.available(localizations: ["Base", "en", "de", "ar"], developmentLocalization: "en")
        #expect(!ids(languages).contains("Base"))
        #expect(Set(ids(languages)) == ["en", "de", "ar"])
    }

    /// A catalogue compiles no folder for untranslated source copy, so the
    /// bundle can omit the development language; the menu must not.
    @Test func languagesAlwaysIncludeTheDevelopmentLanguage() {
        let languages = StoryLanguage.available(localizations: ["Base", "ja"], developmentLocalization: "en")
        #expect(ids(languages) == ["en", "ja"])
    }

    @Test func developmentLanguageComesFirstThenEnglishNameOrder() {
        let languages = StoryLanguage.available(
            localizations: ["zh-Hans", "ja", "en", "ar", "de", "pt-BR"],
            developmentLocalization: "en"
        )
        #expect(ids(languages) == ["en", "ar", "zh-Hans", "de", "ja", "pt-BR"])
    }

    @Test func languagesAreListedOnce() {
        let languages = StoryLanguage.available(localizations: ["en", "de", "de"], developmentLocalization: "en")
        #expect(ids(languages) == ["en", "de"])
    }

    @Test func theAppBundleOffersItsDevelopmentLanguageAndNoBase() throws {
        let languages = ids(StoryLanguage.available(in: .main))
        let development = try #require(Bundle.main.developmentLocalization)
        #expect(languages.first == development)
        #expect(!languages.contains("Base"))
    }

    /// The native name is wrapped in a first-strong isolate (U+2068 … U+2069)
    /// so an Arabic name cannot turn the whole line right to left.
    @Test(arguments: [
        ("ja", "\u{2068}日本語\u{2069} · Japanese"),
        ("ar", "\u{2068}العربية\u{2069} · Arabic"),
        ("pt-BR", "\u{2068}Português (Brasil)\u{2069} · Portuguese (Brazil)"),
        ("en", "English")
    ])
    func titlesGiveTheNativeNameThenTheEnglishName(_ id: String, _ title: String) {
        #expect(StoryLanguage(id).title == title)
    }

    // MARK: Direction

    @Test func automaticLaysArabicOutRightToLeft() {
        #expect(StoryDirection.automatic.resolved(for: StoryLanguage("ar"), inherited: .leftToRight) == .rightToLeft)
    }

    @Test(arguments: ["ja", "de"])
    func automaticLaysLeftToRightLanguagesOutLeftToRight(_ id: String) {
        #expect(StoryDirection.automatic.resolved(for: StoryLanguage(id), inherited: .rightToLeft) == .leftToRight)
    }

    @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func automaticWithSystemKeepsTheInheritedDirection(_ inherited: LayoutDirection) {
        #expect(StoryDirection.automatic.resolved(for: nil, inherited: inherited) == inherited)
    }

    @Test(arguments: [nil, "ar", "de"])
    func overridesWinOverTheLanguage(_ id: String?) {
        let language = id.map(StoryLanguage.init)
        #expect(StoryDirection.leftToRight.resolved(for: language, inherited: .rightToLeft) == .leftToRight)
        #expect(StoryDirection.rightToLeft.resolved(for: language, inherited: .leftToRight) == .rightToLeft)
    }

    // MARK: Persistence

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "CardsTests.Storybook.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    @Test func choicesStartAtSystemAndAutomatic() throws {
        try withDefaults { defaults in
            let options = DisplayOptions(store: defaults, languages: [StoryLanguage("en"), StoryLanguage("ar")])
            #expect(options.language == nil)
            #expect(options.direction == .automatic)
            #expect(options.locale(inherited: Locale(identifier: "en_GB")) == Locale(identifier: "en_GB"))
        }
    }

    @Test func choicesSurviveARelaunch() throws {
        try withDefaults { defaults in
            let languages = [StoryLanguage("en"), StoryLanguage("ar")]
            let first = DisplayOptions(store: defaults, languages: languages)
            first.language = StoryLanguage("ar")
            first.direction = .leftToRight

            let relaunched = DisplayOptions(store: defaults, languages: languages)
            #expect(relaunched.language == StoryLanguage("ar"))
            #expect(relaunched.direction == .leftToRight)
            #expect(relaunched.locale(inherited: .current) == Locale(identifier: "ar"))
            #expect(relaunched.layoutDirection(inherited: .rightToLeft) == .leftToRight)
        }
    }

    @Test func choosingSystemAgainForgetsTheLanguage() throws {
        try withDefaults { defaults in
            let languages = [StoryLanguage("en"), StoryLanguage("de")]
            let first = DisplayOptions(store: defaults, languages: languages)
            first.language = StoryLanguage("de")
            first.language = nil

            #expect(DisplayOptions(store: defaults, languages: languages).language == nil)
        }
    }

    /// A language saved before its translations were removed falls back to
    /// System rather than rendering in a language the app no longer has.
    @Test func aSavedLanguageTheBundleNoLongerHasFallsBackToSystem() throws {
        try withDefaults { defaults in
            let first = DisplayOptions(store: defaults, languages: [StoryLanguage("en"), StoryLanguage("ko")])
            first.language = StoryLanguage("ko")

            #expect(DisplayOptions(store: defaults, languages: [StoryLanguage("en")]).language == nil)
        }
    }

    /// The Storybook's choices never land in the app's standard defaults,
    /// where the shipping app keeps its own settings.
    @Test func choicesStayOutOfTheStandardDefaults() {
        let options = DisplayOptions()
        let previous = (options.language, options.direction)
        defer { (options.language, options.direction) = previous }

        options.language = options.languages.first
        options.direction = .rightToLeft
        let standardKeys = UserDefaults.standard.dictionaryRepresentation().keys
        #expect(!standardKeys.contains { $0.hasPrefix("storybook.") })
    }
}
