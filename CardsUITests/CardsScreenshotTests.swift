import UIKit
import XCTest

/// Captures App Store screenshots. Run via:
///   scripts/capture-screenshots.sh
///
/// Each call to `attach` produces an XCTAttachment in the xcresult bundle with
/// `.keepAlways` lifetime so the capture script can extract it post-test. The
/// app is seeded with the screenshot cards and a fixed location (see
/// ScreenshotSeed), so every run shows the same distances.
final class CardsScreenshotTests: XCTestCase {
    private let seededCards = [
        "Tesco Clubcard",
        "Costa Coffee",
        "Boots Advantage",
        "Westway Climbing",
        "Nectar",
        "IKEA Family"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-screenshotSeed"]
        app.launchEnvironment["CARDS_UI_TESTING"] = "1"
        app.launchEnvironment["CARDS_SCREENSHOT_SEED"] = "1"
        app.launch()
        defer { app.terminate() }

        // iPad names end "_iPad"; other devices take theirs from the capture
        // script, which sets TEST_RUNNER_SCREENSHOT_SUFFIX (for example "_Duo").
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let suffix = isPad ? "_iPad" : ProcessInfo.processInfo.environment["SCREENSHOT_SUFFIX"] ?? ""

        XCTAssertTrue(app.buttons["addCardButton"].waitForExistence(timeout: 5))
        // Cards with locations ask for notifications, for the arrival reminders.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let permission = springboard.alerts.firstMatch
        if permission.waitForExistence(timeout: 5) {
            permission.buttons.element(boundBy: 1).tap()
            XCTAssertTrue(permission.waitForNonExistence(timeout: 3))
        }
        for cardName in seededCards {
            XCTAssertTrue(row(app, cardName).waitForExistence(timeout: 3), "Missing seeded card: \(cardName)")
        }
        attach(app, name: "01_CardList\(suffix)")

        row(app, "Tesco Clubcard").tap()
        XCTAssertTrue(app.descendants(matching: .any)["barcodeView"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["cardProximityText"].firstMatch.waitForExistence(timeout: 3))
        attach(app, name: "02_CardDetail\(suffix)")

        app.buttons["editCardButton"].tap()
        let nameField = app.textFields["Card name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        // The name field takes focus on its own after a moment, bringing up the
        // keyboard when the simulator shows one. Return puts it away. Scrolling
        // would too, but a scroll up shrinks the tab bar to a single button.
        if app.keyboards.firstMatch.waitForExistence(timeout: 4) {
            app.typeText("\n")
            // In case Return does not do it on some display; a swipe is the fallback.
            if !waitForKeyboardToGo(app, timeout: 1.5) {
                app.descendants(matching: .any)["editCardForm"].firstMatch.swipeDown()
            }
        }
        XCTAssertTrue(waitForKeyboardToGo(app, timeout: 3))
        attach(app, name: "03_EditCard\(suffix)")

        // Below the palette on smaller screens, such as the iPhone Duo's outer display.
        let addLocation = app.buttons["Add Location"]
        for _ in 0..<3 where !addLocation.isHittable {
            app.descendants(matching: .any)["editCardForm"].firstMatch.swipeUp()
        }
        addLocation.tap()
        XCTAssertTrue(app.descendants(matching: .any)["locationPickerMap"].firstMatch.waitForExistence(timeout: 5))
        // Map tiles load from the network after the map appears.
        Thread.sleep(forTimeInterval: 4)
        attach(app, name: "04_LocationPicker\(suffix)")
    }

    /// A list row. Its label starts with the card name and goes on to say how
    /// far away the card is.
    @MainActor
    private func row(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    /// Whether the keyboard has left the screen. On the iPhone Duo's outer display
    /// it stays in the hierarchy below the screen once put away, so it never stops existing.
    @MainActor
    private func waitForKeyboardToGo(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        repeat {
            let keyboard = app.keyboards.firstMatch
            if !keyboard.exists || keyboard.frame.minY >= app.frame.maxY {
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
