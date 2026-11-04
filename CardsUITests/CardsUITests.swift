//
//  CardsUITests.swift
//  CardsUITests
//
//  Created by Serby, Paul on 18/12/2024.
//

import XCTest

/// Adds a card and checks the detail screen shows it. Elements are found by
/// identifier, never by their English text, so the same test runs in every
/// language; `CardsArabicUITests` runs it right to left.
class CardsUITests: XCTestCase {
    /// Launch arguments for a variant of the suite, such as another language.
    class var variantArguments: [String] { [] }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAdd() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"] + Self.variantArguments
        app.launch()

        // The store starts empty, so the list shows its own Add Card button.
        let addButton = app.buttons["addFirstCardButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "addFirstCardButton did not appear")
        addButton.tap()

        let nameField = app.textFields["nameTextField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "nameTextField did not appear")
        let codeField = app.textFields["codeTextField"]

        let testName = "Test Name"
        let testCode = "Test Code"
        nameField.tap()
        nameField.typeText(testName)
        codeField.tap()
        codeField.typeText(testCode)

        app.buttons["saveCardButton"].tap()

        let name = app.staticTexts["cardNameText"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "The card's screen did not open")
        XCTAssertTrue(name.label.contains(testName), "Name shows '\(name.label)'")
        let code = app.staticTexts["cardCodeText"]
        XCTAssertTrue(code.label.contains(testCode), "Code shows '\(code.label)'")
    }

    /// Reordering and deleting do not need a drag or a swipe: each card's
    /// menu does both, for pointer, keyboard, Voice Control and Switch
    /// Control users.
    @MainActor
    func testMoveAndDeleteFromTheMenu() throws {
        let app = XCUIApplication.launchForTesting(arguments: Self.variantArguments)

        // The first two seeded cards.
        let tesco = app.buttons[SeededCard.tesco]
        let costa = app.buttons[SeededCard.costa]
        XCTAssertTrue(tesco.waitForExistence(timeout: 5))
        XCTAssertLessThan(tesco.frame.minY, costa.frame.minY)

        let moveDown = app.buttons["moveCardDownMenuItem"]
        XCTAssertTrue(app.openMenu(on: tesco, showing: moveDown), "The card's menu did not open")
        XCTAssertFalse(app.buttons["moveCardUpMenuItem"].exists, "The first card offered to move up")
        moveDown.tap()
        XCTAssertTrue(waitUntil { costa.frame.minY < tesco.frame.minY }, "Tesco did not move below Costa")

        let delete = app.buttons["deleteCardMenuItem"]
        XCTAssertTrue(app.openMenu(on: tesco, showing: delete), "The card's menu did not open")
        delete.tap()
        XCTAssertTrue(waitUntil { !tesco.exists }, "Tesco was not deleted")
        XCTAssertTrue(costa.exists)
    }

    @MainActor
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
    }
}

/// Every test again in Arabic, right to left, as the tests must not depend on
/// the text or its direction. The app is translated into Arabic, so the
/// language alone lays it out right to left; `testLaysOutRightToLeft` fails
/// if that stops, as it would if the translation left the build and iOS fell
/// back to English, left to right.
final class CardsArabicUITests: CardsUITests {
    override static var variantArguments: [String] {
        ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
    }

    /// The first tab, Cards, is drawn on the right.
    @MainActor
    func testLaysOutRightToLeft() {
        let app = XCUIApplication.launchForTesting(seeded: false, arguments: Self.variantArguments)
        let tabs = app.tabBars.buttons
        XCTAssertGreaterThan(
            tabs.element(boundBy: 0).frame.minX,
            tabs.element(boundBy: 1).frame.minX,
            "The Arabic run is laid out left to right"
        )
    }
}
