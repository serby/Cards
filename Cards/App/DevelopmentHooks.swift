import CoreLocation
import OSLog
import SwiftData
import SwiftUI

/// The only way production code reaches `Cards/Development`, which release
/// builds do not compile (see docs/DEVELOPMENT.md). Each hook keeps its own
/// `#if DEBUG` inside, so callers never need one, and in a release build every
/// hook is inert.
@MainActor
enum DevelopmentHooks {
    /// UI tests launch with `-uiTesting` (or `CARDS_UI_TESTING=1`) to get an
    /// in-memory store and the shipping UI. Always false in release.
    static var isUITesting: Bool {
        #if DEBUG
        CommandLine.arguments.contains("-uiTesting")
            || ProcessInfo.processInfo.environment["CARDS_UI_TESTING"] == "1"
        #else
        false
        #endif
    }

    /// Turns UIKit's animations off when launched with `-disableAnimations`, as
    /// every UI test launches the app, so XCUITest never waits for one to end.
    /// It waits for the app to go idle before each query and tap, and on iOS
    /// 26 and 27 a tile's long-press menu leaves an animation running that
    /// never ends, from the drag that lifts the tile under the menu: every step
    /// with the menu up waited 60 s and gave up. Sheets, pushes and menus still
    /// open and close, at once. Not part of `-uiTesting`, so a run in the
    /// simulator for shaping a feature keeps its animations. Does nothing in
    /// release.
    static func disableAnimationsIfRequested() {
        #if DEBUG
        if CommandLine.arguments.contains("-disableAnimations") {
            UIView.setAnimationsEnabled(false)
        }
        #endif
    }

    /// Creates the CloudKit schema in the Development environment when launched
    /// with `-initializeCloudKitSchema`. A failure is logged, not thrown, so
    /// the app still starts. Does nothing in release.
    static func initializeCloudKitSchemaIfRequested() {
        #if DEBUG
        guard CommandLine.arguments.contains("-initializeCloudKitSchema") else { return }
        do {
            try CloudKitSchema.initialize()
        } catch {
            Logger(subsystem: "net.serby.Cards", category: "CloudKitSchema")
                .error("CloudKit schema initialisation failed: \(String(describing: error), privacy: .public)")
        }
        #endif
    }

    /// Inserts the App Store screenshot cards when launched with
    /// `-screenshotSeed` (or `CARDS_SCREENSHOT_SEED=1`). Does nothing in release.
    static func seedScreenshotCards(into container: ModelContainer) throws {
        #if DEBUG
        if screenshotSeedRequested {
            try ScreenshotSeed.insert(into: container.mainContext)
        }
        if screenshotSeedRequested, CommandLine.arguments.contains("-manyScreenshotCards") {
            try ScreenshotSeed.insertMany(into: container.mainContext)
        }
        if CommandLine.arguments.contains("-cardThatCannotDraw") {
            try ScreenshotSeed.insertCardThatCannotDraw(into: container.mainContext)
        }
        #endif
    }

    /// Where the screenshot cards are seen from, with `-screenshotSeed`, so their
    /// distances are the same on every run. Nil otherwise, and always in release.
    static var screenshotLocation: CLLocation? {
        #if DEBUG
        screenshotSeedRequested ? ScreenshotSeed.location : nil
        #else
        nil
        #endif
    }

    /// Whether maps show Apple Maps' points of interest: always, except in the
    /// App Store screenshots, where their real business names don't belong.
    static var mapShowsPointsOfInterest: Bool {
        #if DEBUG
        !screenshotSeedRequested
        #else
        true
        #endif
    }

    /// How the location picker finds and names places: MapKit, except in UI
    /// tests, which search the made-up places in docs/LANGUAGE.md so every run
    /// finds the same ones and no real business reaches a screenshot.
    static var placeSearch: PlaceSearch {
        #if DEBUG
        isUITesting ? .sample : .live
        #else
        .live
        #endif
    }

    /// The notifications the arrival reminders go through: iOS's, except in UI
    /// tests, where nothing is scheduled and permission is never asked. Asked
    /// on every fresh install, iOS's prompt covered the screen under test, and
    /// every test that launched with the seeded cards, which have places,
    /// waited up to five seconds for it to come up.
    static var notifications: NotificationClient {
        #if DEBUG
        isUITesting ? .silent : .live
        #else
        .live
        #endif
    }

    /// How Settings learns what iCloud Sync is doing (DATA-10): from CloudKit,
    /// except in UI tests, whose store is in memory and never syncs, so there it
    /// is up to date as of a few minutes ago, as the App Store screenshot shows.
    static var iCloudSync: ICloudSync {
        #if DEBUG
        isUITesting ? .upToDate(ago: 3 * 60) : .live
        #else
        .live
        #endif
    }

    /// What the app tells its developer (PLAT-14, PLAT-15): Sentry and Google
    /// Analytics, under their switches, except in UI tests and unit tests,
    /// where nothing is ever sent. Debug builds report as "debug", so they are
    /// told apart from the App Store's.
    static var telemetry: Telemetry {
        #if DEBUG
        isUITesting || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ? .silent : .live(environment: "debug")
        #else
        .live(environment: "production")
        #endif
    }

    /// Whether the app counts the days cards are shown on and asks for an App
    /// Store rating (PLAT-8): always, except in UI tests and the screenshots,
    /// where Apple's prompt would cover the screen under test.
    static var asksForReviews: Bool {
        #if DEBUG
        !isUITesting && !screenshotSeedRequested
        #else
        true
        #endif
    }

    #if DEBUG
    private static var screenshotSeedRequested: Bool {
        CommandLine.arguments.contains("-screenshotSeed")
            || ProcessInfo.processInfo.environment["CARDS_SCREENSHOT_SEED"] == "1"
    }
    #endif

    /// Tabs that only exist while developing: Development, with the Storybook
    /// and the other tools, kept out of UI tests so they see the shipping UI.
    /// Never shown in release.
    @TabContentBuilder<AppTab>
    static var tabs: some TabContent<AppTab> {
        // A tab builder cannot be empty, so release keeps the tab and drops it here.
        if showsDevelopmentTab {
            Tab(developmentTitle, systemImage: "hammer", value: AppTab.development) {
                developmentTools
            }
        }
    }

    /// A plain `String`, not a literal key, so the development-only tab title
    /// stays out of the string catalogue and is never sent for translation.
    private static let developmentTitle = "Development"

    private static var showsDevelopmentTab: Bool {
        #if DEBUG
        !isUITesting
        #else
        false
        #endif
    }

    @ViewBuilder
    private static var developmentTools: some View {
        #if DEBUG
        DevelopmentView()
        #endif
    }
}
