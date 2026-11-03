import SwiftUI

/// A language the Storybook can show a story in: one of the localisations
/// compiled into the app bundle. The stage sets `\.locale` to it; see
/// `DisplayOptions` for what follows that and what does not.
struct StoryLanguage: Identifiable, Hashable, Sendable {
    /// The localisation as the bundle names its folder: "de", "pt-BR", "zh-Hans".
    let id: String

    init(_ id: String) {
        self.id = id
    }

    var locale: Locale {
        Locale(identifier: id)
    }

    /// The language's name in English: "Japanese", "Portuguese (Brazil)".
    var englishName: String {
        Locale(identifier: "en").localizedString(forIdentifier: id) ?? id
    }

    /// The language's name in itself, capitalised as the system's language
    /// lists show it: "Português (Brasil)", "日本語".
    var nativeName: String {
        let name = locale.localizedString(forIdentifier: id) ?? id
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }

    /// The menu title, native name first so a speaker recognises it:
    /// "日本語 · Japanese". English, whose two names match, is just "English".
    /// The native name is a bidi isolate (FSI…PDI): otherwise "العربية · Arabic"
    /// starts with a right-to-left letter, the line takes that direction and
    /// reads "Arabic · العربية".
    var title: String {
        nativeName == englishName ? englishName : "\u{2068}\(nativeName)\u{2069} · \(englishName)"
    }

    /// The direction the language's script runs in.
    var characterDirection: LayoutDirection {
        Locale.Language(identifier: id).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }
}

extension StoryLanguage {
    /// Every localisation in `bundle`, so a newly translated language appears
    /// in the menu with no code change.
    static func available(in bundle: Bundle = .main) -> [Self] {
        available(localizations: bundle.localizations, developmentLocalization: bundle.developmentLocalization)
    }

    /// `Base` is the storyboard fallback, not a language, so it is left out.
    /// The development language is always in: a String Catalogue compiles no
    /// folder for copy that is still the source, so the bundle may not list
    /// it. The development language comes first, then the rest by English name.
    static func available(localizations: [String], developmentLocalization: String?) -> [Self] {
        let development = developmentLocalization.flatMap { isBase($0) ? nil : $0 }
        let codes = Set(localizations.filter { !isBase($0) } + [development].compactMap { $0 })
        return codes.map(Self.init).sorted { lhs, rhs in
            if (lhs.id == development) != (rhs.id == development) {
                return lhs.id == development
            }
            return lhs.englishName.localizedStandardCompare(rhs.englishName) == .orderedAscending
        }
    }

    private static func isBase(_ code: String) -> Bool {
        code.caseInsensitiveCompare("Base") == .orderedSame
    }
}

/// The layout direction the Storybook gives a story.
enum StoryDirection: String, CaseIterable, Identifiable, Sendable {
    /// The chosen language's script direction, or the app's own with System.
    case automatic
    case leftToRight
    case rightToLeft

    var id: String {
        rawValue
    }

    /// `inherited` is the direction the Storybook itself lays out in, which
    /// Automatic keeps when the language is System.
    func resolved(for language: StoryLanguage?, inherited: LayoutDirection) -> LayoutDirection {
        switch self {
        case .automatic:
            return language?.characterDirection ?? inherited
        case .leftToRight:
            return .leftToRight
        case .rightToLeft:
            return .rightToLeft
        }
    }

    /// The menu title. Automatic says what it resolves to, so the menu shows
    /// the direction in force.
    func title(for language: StoryLanguage?, inherited: LayoutDirection) -> String {
        switch self {
        case .automatic:
            let resolved = resolved(for: language, inherited: inherited) == .rightToLeft ? "right to left" : "left to right"
            return "Automatic (\(resolved))"
        case .leftToRight:
            return "Left to right"
        case .rightToLeft:
            return "Right to left"
        }
    }
}
