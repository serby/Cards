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
        // Cards with locations ask for notifications, for the Lock Screen arrivals.
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
        if isPad { return }

        app.buttons["editCardButton"].tap()
        let nameField = app.textFields["Card name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        // The name field takes focus on its own after a moment, bringing up the
        // keyboard when the simulator shows one. Scrolling the form puts it away.
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        _ = XCTWaiter.wait(for: [expectation(for: focused, evaluatedWith: nameField)], timeout: 3)
        app.descendants(matching: .any)["editCardForm"].firstMatch.swipeDown()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        attach(app, name: "03_EditCard\(suffix)")

        app.buttons["Add Location"].tap()
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

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
