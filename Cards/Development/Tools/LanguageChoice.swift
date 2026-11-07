import Foundation

/// One row of the Language tool (DEV-4): System, which removes the app's
/// language override so it follows the iPhone, or a language the app bundle
/// has, named in itself. Pure, so the tests check the list without touching
/// the app's settings.
struct LanguageChoice: Identifiable, Hashable, Sendable {
    /// The language, or nil for System.
    let language: StoryLanguage?

    var id: String {
        language?.id ?? "system"
    }

    /// The name in the language itself, as the iPhone's own language list
    /// writes it ("Deutsch", "日本語"), or "System".
    var name: String {
        language?.nativeName ?? "System"
    }

    /// The name in English ("German"), or what System means. Nil for a
    /// language whose two names are the same, as English's are.
    var detail: String? {
        guard let language else { return "The iPhone's language" }
        return language.englishName == language.nativeName ? nil : language.englishName
    }

    /// What the override becomes: ["de"], or none for System, which removes it.
    var override: [String] {
        language.map { [$0.id] } ?? []
    }

    /// What the tool asks before the app closes.
    var confirmationTitle: String {
        "Open in \(language?.nativeName ?? "the iPhone's Language")?"
    }

    /// What the tool says before the app closes.
    var confirmationMessage: String {
        "Card Barcodes closes so it can open in \(language?.nativeName ?? "the iPhone's language"). Open it again from the Home Screen."
    }
}

extension LanguageChoice {
    static let system = Self(language: nil)

    /// System, then `languages`: by default every language in the app bundle,
    /// in the Storybook's order, the development language first and the rest
    /// by English name.
    static func all(_ languages: [StoryLanguage] = StoryLanguage.available()) -> [Self] {
        [.system] + languages.map { Self(language: $0) }
    }

    /// The choice `override` makes among `choices`, matched as iOS matches an
    /// app's languages to the ones it has, so "de-GB" ticks Deutsch. System when
    /// there is no override.
    static func current(for override: [String], in choices: [Self]) -> Self {
        guard !override.isEmpty else { return .system }
        let ids = choices.compactMap(\.language?.id)
        let match = Bundle.preferredLocalizations(from: ids, forPreferences: override).first
        return choices.first { $0.language?.id == match } ?? .system
    }
}
