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
            Tab("Development", systemImage: "hammer", value: AppTab.development) {
                developmentTools
            }
        }
    }

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
