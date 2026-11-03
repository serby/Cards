import UIKit
import XCTest

/// Captures App Store screenshots. Run via:
///   scripts/capture-screenshots.sh
///
/// Each call to `attach` produces an XCTAttachment in the xcresult bundle with
/// `.keepAlways` lifetime so the capture script can extract it post-test.
final class CardsScreenshotTests: XCTestCase {

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

        XCTAssertTrue(app.buttons["addCardButton"].waitForExistence(timeout: 5))
        let expectedCards = [
            "Tesco Clubcard",
            "Boots Advantage",
            "Costa Coffee",
            "Nectar",
            "Sainsbury's Nectar",
            "IKEA Family"
        ]
        for cardName in expectedCards {
            XCTAssertTrue(
                app.buttons[cardName].waitForExistence(timeout: 3),
                "Missing seeded card: \(cardName)"
            )
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            attach(app, name: "01_CardList_iPad")
            return
        }

        attach(app, name: "01_CardList")

        app.buttons["addCardButton"].tap()
        let nameField = app.textFields["nameTextField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        attach(app, name: "02_AddCard")

        let codeField = app.textFields["codeTextField"]
        let testName = "Snapshot Test Card"
        let testCode = "9876543210987"
        nameField.tap()
        nameField.typeText(testName)
        codeField.tap()
        codeField.typeText(testCode)
        app.buttons["saveCardButton"].tap()
        let name = app.staticTexts["cardNameText"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(name.label.contains(testName))
        XCTAssertTrue(app.staticTexts["cardCodeText"].label.contains(testCode))

        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        backButton.tap()
        XCTAssertTrue(app.buttons["addCardButton"].waitForExistence(timeout: 3))

        // By position, as tab titles are translated. The order of the elements
        // stays the same right to left; only the drawing flips.
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.switches["brightnessBoostToggle"].waitForExistence(timeout: 5))
        attach(app, name: "03_Settings")
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
