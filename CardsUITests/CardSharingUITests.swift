import XCTest

/// Sharing a card from the card screen, and adding a card from a share link
/// (SHARE-1, SHARE-2, SHARE-3).
final class CardSharingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The share button sits in the card screen's toolbar and offers a link and an image.
    @MainActor
    func testShareMenuOffersALinkAndAnImage() throws {
        let app = launch()
        open("Nectar", in: app)

        let share = app.buttons["shareCardButton"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertEqual(share.label, "Share card")
        share.tap()

        let link = app.buttons["Share Link"]
        let image = app.buttons["Share Image"]
        XCTAssertTrue(link.waitForExistence(timeout: 3))
        XCTAssertTrue(image.exists)

        // The image is drawn when the share sheet asks for it, and the sheet opens.
        image.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10), "The share sheet did not open")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-screenshotSeed"]
        app.launch()
        // Cards with places ask for notifications once; answer so the alert does not cover the app.
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 5) {
            alert.buttons.element(boundBy: 1).tap()
        }
        return app
    }

    @MainActor
    private func open(_ name: String, in app: XCUIApplication) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No card called \(name)")
        row.tap()
    }
}
