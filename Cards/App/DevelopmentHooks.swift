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
    /// with `-initializeCloudKitSchema`, before SwiftData opens the store at
    /// `storeURL`. Does nothing in release.
    static func initializeCloudKitSchemaIfRequested(storeURL: URL) throws {
        #if DEBUG
        if CommandLine.arguments.contains("-initializeCloudKitSchema") {
            try CloudKitSchema.initialize(storeURL: storeURL)
        }
        #endif
    }

    /// Inserts the App Store screenshot cards when launched with
    /// `-screenshotSeed` (or `CARDS_SCREENSHOT_SEED=1`). Does nothing in release.
    static func seedScreenshotCards(into container: ModelContainer) throws {
        #if DEBUG
        let requested = CommandLine.arguments.contains("-screenshotSeed")
            || ProcessInfo.processInfo.environment["CARDS_SCREENSHOT_SEED"] == "1"
        if requested {
            try ScreenshotSeed.insert(into: container.mainContext)
        }
        #endif
    }

    /// Tabs that only exist while developing: the Storybook, kept out of UI
    /// tests so they see the shipping UI. Never shown in release.
    @TabContentBuilder<Never>
    static var tabs: some TabContent<Never> {
        // A tab builder cannot be empty, so release keeps the tab and drops it here.
        if showsStorybook {
            Tab("Storybook", systemImage: "square.grid.2x2") {
                storybook
            }
        }
    }

    private static var showsStorybook: Bool {
        #if DEBUG
        !isUITesting
        #else
        false
        #endif
    }

    @ViewBuilder
    private static var storybook: some View {
        #if DEBUG
        StorybookView()
        #endif
    }
}
