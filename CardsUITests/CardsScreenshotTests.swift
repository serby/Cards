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

    /// Launches with the screenshot cards in custom order and without the card
    /// for where you are, whatever the simulator's own settings say, so every
    /// capture shows the same grid. UI tests never ask to send notifications
    /// (`DevelopmentHooks.notifications`), so no prompt covers the captures.
    @MainActor
    private func launchSeeded() -> XCUIApplication {
        // The cards in custom order, without the card for where you are and with
        // distances in the locale's own units, whatever the simulator's own
        // settings say, so every capture shows the same grid.
        let app = XCUIApplication.forTesting([
            "-screenshotSeed", "-cardSortOrder", "custom", "-showsCardWhereYouAre", "NO", "-distanceUnits", "automatic"
        ])
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
