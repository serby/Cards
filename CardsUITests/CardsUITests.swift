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
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-screenshotSeed"] + Self.variantArguments
        app.launchEnvironment["CARDS_SCREENSHOT_SEED"] = "1"
        app.launch()

        // The first two seeded cards.
        let tesco = app.buttons["cardRow_634004024987531"]
        let boots = app.buttons["cardRow_9780201379624"]
        XCTAssertTrue(tesco.waitForExistence(timeout: 5))
        XCTAssertLessThan(tesco.frame.minY, boots.frame.minY)

        let moveDown = app.buttons["moveCardDownMenuItem"]
        XCTAssertTrue(openMenu(on: tesco, showing: moveDown), "The card's menu did not open")
        XCTAssertFalse(app.buttons["moveCardUpMenuItem"].exists, "The first card offered to move up")
        moveDown.tap()
        XCTAssertTrue(waitUntil { boots.frame.minY < tesco.frame.minY }, "Tesco did not move below Boots")

        let delete = app.buttons["deleteCardMenuItem"]
        XCTAssertTrue(openMenu(on: tesco, showing: delete), "The card's menu did not open")
        delete.tap()
        XCTAssertTrue(waitUntil { !tesco.exists }, "Tesco was not deleted")
        XCTAssertTrue(boots.exists)
    }

    /// Long-presses `row` until its menu shows `item`. A press while the list
    /// is still settling, after launch or a move, can miss, so it tries again.
    @MainActor
    private func openMenu(on row: XCUIElement, showing item: XCUIElement) -> Bool {
        for _ in 0..<3 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            row.press(forDuration: 1.2)
            if item.waitForExistence(timeout: 3) { return true }
        }
        return false
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

/// Every test again in Arabic, right to left. Nothing is translated yet, but
/// the layout direction is real, and the tests must not depend on the text.
final class CardsArabicUITests: CardsUITests {
    override static var variantArguments: [String] {
        ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
    }
}
