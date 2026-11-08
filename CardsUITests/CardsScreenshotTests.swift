import UIKit
import XCTest

/// Captures App Store screenshots. Run via:
///   node scripts/capture-screenshots.ts
///
/// Each call to `attach` produces an XCTAttachment in the xcresult bundle with
/// `.keepAlways` lifetime so the capture script can extract it post-test. The
/// app is seeded with the screenshot cards and a fixed location (see
/// ScreenshotSeed), so every run shows the same distances. The list, a card,
/// the edit form and the map come from one run through the app; the share menu
/// has a test of its own. Elements are found by identifier, and the system
/// prompt's buttons by position, so the test runs in every store locale.
final class CardsScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureScreenshots() throws {
        let app = launchSeeded()
        defer { app.terminate() }

        for row in SeededCard.all {
            XCTAssertTrue(app.buttons[row].appears(within: 3), "Missing seeded card: \(row)")
        }
        attach(app, name: "01_CardList\(suffix)")

        app.buttons[SeededCard.joesMarket].tap()
        XCTAssertTrue(app.descendants(matching: .any)["barcodeView"].firstMatch.appears(within: 5))
        XCTAssertTrue(app.descendants(matching: .any)["cardProximityText"].firstMatch.appears(within: 3))
        attach(app, name: "02_CardDetail\(suffix)")

        app.buttons["editCardButton"].tap()
        let nameField = app.textFields["nameTextField"]
        XCTAssertTrue(nameField.appears(within: 5))
        // The form opens with the keyboard down (CARD-5).
        XCTAssertTrue(waitForKeyboardToGo(app, timeout: 3))
        attach(app, name: "03_EditCard\(suffix)")

        // Below the palette on smaller screens, such as the iPhone Duo's outer display.
        let addLocation = app.buttons["addLocationRowButton"]
        for _ in 0..<3 where !addLocation.isHittable {
            app.descendants(matching: .any)["editCardForm"].firstMatch.swipeUp()
        }
        addLocation.tap()
        XCTAssertTrue(app.descendants(matching: .any)["locationPickerMap"].firstMatch.appears(within: 5))
        // Map tiles load from the network after the map appears.
        Thread.sleep(forTimeInterval: 4)
        attach(app, name: "04_LocationPicker\(suffix)")
    }

    /// The card screen with its share menu open, offering the card as a link or
    /// a picture (SHARE-1, SHARE-2). A test of its own, so it starts from the
    /// list whatever the other capture left on screen.
    @MainActor
    func testCaptureShareScreenshot() throws {
        let app = launchSeeded()
        defer { app.terminate() }

        let card = app.buttons[SeededCard.honeycomb]
        XCTAssertTrue(card.appears(within: 3))
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["barcodeView"].firstMatch.appears(within: 5))
        let share = app.buttons["shareCardButton"]
        XCTAssertTrue(share.appears(within: 3))
        share.tap()
        XCTAssertTrue(app.buttons["shareLinkButton"].appears(within: 3))
        XCTAssertTrue(app.buttons["shareImageButton"].exists)
        // The menu grows out of its button; let it finish.
        Thread.sleep(forTimeInterval: 1)
        attach(app, name: "06_ShareCard\(suffix)")
    }

    /// The Cards tab with the card for where you are in full above the grid
    /// (SET-3), which leads the App Store images: at the shop, its card is ready.
    @MainActor
    func testCaptureCardWhereYouAreScreenshot() throws {
        let app = launchSeeded(showsCardWhereYouAre: true)
        defer { app.terminate() }
        XCTAssertTrue(app.descendants(matching: .any)["cardWhereYouAre"].firstMatch.appears(within: 5))
        attach(app, name: "07_CardWhereYouAre\(suffix)")
    }

    /// Settings at iCloud, Data and Privacy: where the cards are kept, export,
    /// and Share Diagnostics (DATA-8, DATA-2, PLAT-11).
    @MainActor
    func testCapturePrivacyScreenshot() throws {
        let app = launchSeeded()
        defer { app.terminate() }
        app.settingsTab.tap()
        XCTAssertTrue(app.collectionViews.firstMatch.appears(within: 5))
        let header = app.descendants(matching: .any)["iCloudSectionHeader"].firstMatch
        // The list only makes its rows as they come on screen.
        for _ in 0..<8 where !header.exists {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(header.exists, "iCloud is not on screen")
        // Dragged, and held before letting go so it doesn't run on, until iCloud
        // is near the top and Data and Privacy follow it on screen.
        let target = app.frame.height * 0.11
        if header.frame.minY > target {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.85))
            let end = start.withOffset(CGVector(dx: 0, dy: target - header.frame.minY))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.6)
        }
        Thread.sleep(forTimeInterval: 1)
        attach(app, name: "08_Privacy\(suffix)")
    }

    /// A grid full of cards, for "as many as you like" (-manyScreenshotCards).
    @MainActor
    func testCaptureManyCardsScreenshot() throws {
        let app = launchSeeded(extra: ["-manyScreenshotCards"])
        defer { app.terminate() }
        XCTAssertTrue(app.buttons[SeededCard.joesMarket].appears(within: 5))
        Thread.sleep(forTimeInterval: 1)
        attach(app, name: "09_ManyCards\(suffix)")
    }

    /// Launches with the screenshot cards in custom order and, unless asked for,
    /// without the card for where you are, whatever the simulator's own settings
    /// say, so every capture shows the same grid. UI tests never ask to send
    /// notifications (`DevelopmentHooks.notifications`), so no prompt covers the captures.
    @MainActor
    private func launchSeeded(showsCardWhereYouAre: Bool = false, extra: [String] = []) -> XCUIApplication {
        // In the listing's language and region, which the capture script runs
        // in, rather than the British English UI tests pick when not told; and
        // distances in the locale's own units, whatever the simulator's settings say.
        let language = ProcessInfo.processInfo.environment["SYSTEM_LANGUAGE"] ?? "en"
        let region = Locale.current.region?.identifier ?? "GB"
        let app = XCUIApplication.forTesting([
            "-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_\(region)",
            "-screenshotSeed", "-cardSortOrder", "custom", "-showsCardWhereYouAre", showsCardWhereYouAre ? "YES" : "NO",
            "-distanceUnits", "automatic", "-mapsApp", "appleMaps"
        ] + extra)
        app.launchEnvironment["CARDS_UI_TESTING"] = "1"
        app.launchEnvironment["CARDS_SCREENSHOT_SEED"] = "1"
        app.launch()

        XCTAssertTrue(app.buttons["addCardButton"].appears(within: 5))
        return app
    }

    /// The end of every screenshot's name. iPad names end "_iPad"; other devices
    /// take theirs from the capture script, which sets
    /// TEST_RUNNER_SCREENSHOT_SUFFIX (for example "_Duo").
    @MainActor
    private var suffix: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "_iPad" : ProcessInfo.processInfo.environment["SCREENSHOT_SUFFIX"] ?? ""
    }

    /// Whether the keyboard has left the screen. On the iPhone Duo's outer display
    /// it stays in the hierarchy below the screen once put away, so it never stops existing.
    @MainActor
    private func waitForKeyboardToGo(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        repeat {
            // One snapshot, so the keyboard cannot go between checking it and reading its frame.
            guard let keyboard = try? app.keyboards.firstMatch.snapshot() else { return true }
            if keyboard.frame.minY >= app.frame.maxY {
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date.now < deadline
        return false
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
