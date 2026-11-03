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

        let addButton = app.buttons["addCardButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "addCardButton did not appear")
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
}

/// Every test again in Arabic, right to left. Nothing is translated yet, but
/// the layout direction is real, and the tests must not depend on the text.
final class CardsArabicUITests: CardsUITests {
    override static var variantArguments: [String] {
        ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
    }
}
