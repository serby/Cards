import Foundation
import SwiftUI

/// The app's own language override, which the Language tool sets (DEV-4): the
/// `AppleLanguages` default in the app's own domain, which iOS reads when it
/// opens the app, and quitting, so that it opens again in the new language.
/// Injected, so stories and previews never change the app's language or close it.
struct AppLanguageClient: Sendable {
    /// The languages the override puts first, such as ["de"]. Empty when there
    /// is none and the app follows the iPhone's languages.
    var override: @MainActor @Sendable () -> [String]
    /// Sets the override; an empty list removes it.
    var setOverride: @MainActor @Sendable ([String]) -> Void
    /// Ends the app.
    var quit: @MainActor @Sendable () -> Void

    /// Sets the override `choice` makes, or removes it for System, then quits:
    /// iOS chooses an app's language only when it opens it.
    @MainActor
    func open(in choice: LanguageChoice) {
        setOverride(choice.override)
        quit()
    }
}

extension AppLanguageClient {
    /// The app's standard defaults, and `exit`, which is acceptable in a tool
    /// that only debug builds have.
    static let live = defaults(suiteName: nil, domain: Bundle.main.bundleIdentifier ?? "", quit: { exit(0) })

    /// The override kept in the defaults suite `suiteName` (nil for the app's
    /// standard defaults), whose own domain is `domain`, calling `quit` to end
    /// the app. It reads that domain alone: `object(forKey:)` falls back to the
    /// iPhone's languages in the global domain, so it would always find some,
    /// and System would never be ticked. `UserDefaults` is not `Sendable`, so
    /// each call opens the suite by name.
    static func defaults(
        suiteName: String?,
        domain: String,
        quit: @escaping @MainActor @Sendable () -> Void
    ) -> Self {
        Self(
            override: {
                UserDefaults(suiteName: suiteName)?.persistentDomain(forName: domain)?[key] as? [String] ?? []
            },
            setOverride: { languages in
                let defaults = UserDefaults(suiteName: suiteName)
                if languages.isEmpty {
                    defaults?.removeObject(forKey: key)
                } else {
                    defaults?.set(languages, forKey: key)
                }
            },
            quit: quit
        )
    }

    /// The default iOS chooses an app's language from.
    static let key = "AppleLanguages"
}

extension EnvironmentValues {
    @Entry var appLanguageClient = AppLanguageClient.live
}
