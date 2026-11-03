import SwiftUI

public enum ColourSchemeChoice: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    var preferred: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

/// Display conditions applied to whichever story is on screen, so a layout can
/// be checked in dark mode, at accessibility text sizes, in another language
/// and right to left without leaving the storybook.
@MainActor
@Observable
public final class DisplayOptions {
    public var colourScheme: ColourSchemeChoice = .system
    public var typeSize: DynamicTypeSize = .large

    /// The language the stage renders in; nil is System, the device's own.
    ///
    /// It sets the stage's `\.locale`, so whatever SwiftUI resolves as it
    /// renders follows it: `Text` and `Label` from a key or a
    /// `LocalizedStringResource`, prompts, picker items, the titles, messages
    /// and `Text` buttons of alerts and dialogs, toolbar items a story adds,
    /// sheets it presents, `FormatStyle`s in a `Text` or a key's
    /// interpolation, and SwiftUI's own copy (`EditButton`, `DatePicker`,
    /// `ContentUnavailableView.search`).
    ///
    /// Anything resolved before SwiftUI sees it, or drawn by UIKit, keeps the
    /// app's language: `String(localized:)` (VoiceOver announcements,
    /// notifications, import results, the "Pinned location" name),
    /// `.formatted()` strings, the OK and Cancel buttons the system adds to
    /// alerts and dialogs, and the keyboard. Check those by running the app in
    /// the language. Checked on iOS 18.1 with a throwaway German and Arabic
    /// probe; see docs/DEVELOPMENT.md, rule 4.
    var language: StoryLanguage? {
        didSet { store.set(language?.id, forKey: Keys.language) }
    }

    /// Reaches everything on the stage except a sheet it presents, which keeps
    /// the app's direction (while taking the language).
    var direction: StoryDirection {
        didSet { store.set(direction.rawValue, forKey: Keys.direction) }
    }

    /// Every localisation in the app bundle, for the language menu.
    let languages: [StoryLanguage]

    @ObservationIgnored private let store: UserDefaults

    public convenience init() {
        self.init(store: Self.storybookDefaults, languages: StoryLanguage.available())
    }

    /// Restores the language and direction saved in `store`. A saved language
    /// the bundle no longer has falls back to System.
    init(store: UserDefaults, languages: [StoryLanguage]) {
        self.store = store
        self.languages = languages
        let savedLanguage = store.string(forKey: Keys.language)
        language = languages.first { $0.id == savedLanguage }
        direction = store.string(forKey: Keys.direction).flatMap(StoryDirection.init(rawValue:)) ?? .automatic
    }

    static let typeSizes: [DynamicTypeSize] = [
        .xSmall,
        .large,
        .xxxLarge,
        .accessibility3,
        .accessibility5
    ]

    /// The stage's `\.locale`: the chosen language, or `inherited` with System.
    func locale(inherited: Locale) -> Locale {
        language?.locale ?? inherited
    }

    /// The stage's `\.layoutDirection`.
    func layoutDirection(inherited: LayoutDirection) -> LayoutDirection {
        direction.resolved(for: language, inherited: inherited)
    }

    /// The choices persist in their own defaults suite rather than the app's
    /// standard defaults, so nothing the Storybook saves sits beside, or could
    /// be read as, a setting of the app. The keys are prefixed too, in case
    /// the suite is ever unavailable.
    private static let storybookDefaults = UserDefaults(suiteName: "net.serby.Cards.Storybook") ?? .standard

    private enum Keys {
        static let language = "storybook.language"
        static let direction = "storybook.direction"
    }
}

extension DynamicTypeSize {
    var label: String {
        switch self {
        case .xSmall:
            return "xSmall"
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        case .xLarge:
            return "xLarge"
        case .xxLarge:
            return "xxLarge"
        case .xxxLarge:
            return "xxxLarge"
        case .accessibility1:
            return "A11y 1"
        case .accessibility2:
            return "A11y 2"
        case .accessibility3:
            return "A11y 3"
        case .accessibility4:
            return "A11y 4"
        case .accessibility5:
            return "A11y 5"
        @unknown default:
            return "Unknown"
        }
    }
}
