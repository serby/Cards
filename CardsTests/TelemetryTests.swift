@testable import Cards
import Foundation
import Testing

/// What Share Diagnostics and Share Usage Data may send (PLAT-14, PLAT-15):
/// only fixed words from the app, never a card, a place or anything typed.
struct TelemetryTests {
    /// Every event, with each of its values.
    private static let events: [AppEvent] =
        AppScreen.allCases.map(AppEvent.screen)
        + CardSource.allCases.map(AppEvent.cardAdded)
        + CardEntry.allCases.map(AppEvent.cardOpened)
        + [.barcodeShown(brightnessBoost: true), .barcodeShown(brightnessBoost: false)]
        + CountBand.allCases.map(AppEvent.cardsExported)
        + ImportSource.allCases.flatMap { source in CountBand.allCases.map { AppEvent.cardsImported(source, added: $0) } }
        + AppSetting.allCases.map { AppEvent.settingChanged($0, to: "on") }

    /// The words an event's values can be, all of them the app's own.
    private static let fixedWords: Set<String> = Set(
        AppScreen.allCases.map(\.rawValue) + CardSource.allCases.map(\.rawValue) + CardEntry.allCases.map(\.rawValue)
            + ImportSource.allCases.map(\.rawValue) + CountBand.allCases.map(\.rawValue) + AppSetting.allCases.map(\.rawValue)
            + ["on", "off"] + DistanceUnits.allCases.map(\.rawValue) + MapsApp.allCases.map(\.rawValue)
    )

    @Test(arguments: events)
    func everyValueIsAFixedWordOfTheApps(_ event: AppEvent) {
        for (key, value) in event.parameters {
            #expect(Self.fixedWords.contains(value), "\(event.name)'s \(key) is \(value), which is not one of the app's own words")
        }
    }

    /// Google Analytics takes names of up to 40 letters, digits and underscores.
    @Test(arguments: events)
    func namesAreWhatGoogleAnalyticsTakes(_ event: AppEvent) {
        let allowed = CharacterSet.lowercaseLetters.union(.decimalDigits).union(CharacterSet(charactersIn: "_"))
        for name in [event.name] + Array(event.parameters.keys) {
            #expect(name.count <= 40)
            #expect(name.unicodeScalars.allSatisfy(allowed.contains), "\(name)")
        }
    }

    @Test(arguments: [(0, CountBand.none), (1, .few), (5, .few), (6, .some), (20, .some), (21, .many), (500, .many), (-3, .none)])
    func countsAreBands(_ count: Int, _ band: CountBand) {
        #expect(CountBand(count) == band)
    }

    @Test func tapsAreDroppedAndTheAppsOwnBreadcrumbsKept() {
        #expect(DiagnosticsPolicy.keepsBreadcrumb(category: DiagnosticsPolicy.appCategory))
        #expect(DiagnosticsPolicy.keepsBreadcrumb(category: "app.lifecycle"))
        for category in ["touch", "ui.click", "ui.lifecycle", "navigation", "http", "console", "query", "user"] {
            #expect(!DiagnosticsPolicy.keepsBreadcrumb(category: category), "\(category) is kept")
        }
    }

    @Test func sentryStartsOnlyWithADSN() {
        #expect(DiagnosticsPolicy.dsn(in: [:]) == nil)
        #expect(DiagnosticsPolicy.dsn(in: ["SentryDSN": "  "]) == nil)
        #expect(DiagnosticsPolicy.dsn(in: ["SentryDSN": "https://key@o1.ingest.sentry.io/2"]) == "https://key@o1.ingest.sentry.io/2")
    }

    @Test func reportsWaitingToBeSentAreSentrysAndSentryCrashsFolders() {
        let caches = URL(filePath: "/caches", directoryHint: .isDirectory)
        #expect(DiagnosticsPolicy.pendingReports(in: caches).map(\.path) == ["/caches/io.sentry", "/caches/SentryCrash"])
    }

    /// The app ships with Google Analytics collecting nothing by itself, so
    /// only the switch turns it on, and with no advertising consent.
    @Test func theAppShipsWithAnalyticsAndAdvertisingOff() throws {
        let info = try #require(Bundle.main.infoDictionary)
        for key in [
            "FIREBASE_ANALYTICS_COLLECTION_ENABLED", "GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED", "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE",
            "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA", "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS",
            "GOOGLE_ANALYTICS_REGISTRATION_WITH_AD_NETWORK_ENABLED", "FirebaseAppDelegateProxyEnabled"
        ] {
            #expect(info[key] as? Bool == false, "\(key) is not false")
        }
    }
}
