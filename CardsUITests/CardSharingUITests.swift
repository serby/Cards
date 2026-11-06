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
        openCard("Nectar", in: app)

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

    /// A share link shows the card, Add Card adds and opens it, and the same
    /// link again finds it already here and offers to open it.
    @MainActor
    func testAddACardFromAShareLink() throws {
        let app = launch()
        let link = "cards://cards/add#" + Self.payload(
            #"{"v":1,"name":"Westway Library","code":"LIB-2026","type":"Code 128","color":"teal","#
                + #""symbol":"books.vertical.fill","notifiesOnArrival":true,"#
                + #""places":[{"name":"Westway","latitude":51.5203,"longitude":-0.2094,"radius":150}]}"#
        )
        try open(link, in: app)

        XCTAssertTrue(app.navigationBars["Add Card?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Card name: Westway Library"].exists)
        let place = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Westway,")).firstMatch
        XCTAssertTrue(place.exists, "The sheet lists the card's place")
        app.buttons["addSharedCardButton"].tap()

        // The sheet closes on the new card's screen.
        XCTAssertTrue(app.buttons["editCardButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Add Card?"].exists)
        XCTAssertTrue(app.staticTexts["Card name: Westway Library"].exists)

        try open(link, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["sharedCardAlreadyAddedMessage"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["addSharedCardButton"].exists)
        app.buttons["openSharedCardButton"].tap()
        XCTAssertTrue(app.buttons["editCardButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Card name: Westway Library"].exists)
    }

    /// A link whose card cannot be read says so and adds nothing.
    @MainActor
    func testALinkWithoutACardSaysSo() throws {
        let app = launch()
        try open("cards://cards/add#not-a-card", in: app)
        XCTAssertTrue(app.staticTexts["This link doesn't contain a card."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["addSharedCardButton"].exists)
        let done = app.buttons["cancelSharedCardButton"]
        XCTAssertEqual(done.label, "Done")
        done.tap()
        XCTAssertTrue(app.buttons["addCardButton"].waitForExistence(timeout: 5))
    }

    /// Opens `link` as another app would, accepting iOS's question about opening
    /// this app. `XCUIApplication.open` relaunches the app, which would empty its
    /// in-memory store.
    @MainActor
    private func open(_ link: String, in app: XCUIApplication) throws {
        XCUIDevice.shared.system.open(try XCTUnwrap(URL(string: link)))
        let openButton = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"]
        if openButton.waitForExistence(timeout: 3) {
            openButton.tap()
        }
    }

    /// `json` as a share link's payload: base64url without padding.
    private static func payload(_ json: String) -> String {
        Data(json.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
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
    private func openCard(_ name: String, in app: XCUIApplication) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No card called \(name)")
        row.tap()
    }
}
