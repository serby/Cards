//
//  CardsUITests.swift
//  CardsUITests
//
//  Created by Serby, Paul on 18/12/2024.
//

import XCTest

final class CardsUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    @MainActor
    func debugElements(_ app: XCUIApplication) {
        print("=== DEBUG: All TextFields ===")
        for textField in app.textFields.allElementsBoundByIndex {
            print("TextField: '\(textField.identifier)' - label: '\(textField.label)' - exists: \(textField.exists)")
        }
        print("=== DEBUG: All Buttons ===")
        for button in app.buttons.allElementsBoundByIndex {
            print("Button: '\(button.identifier)' - label: '\(button.label)' - exists: \(button.exists)")
        }
        print("=== DEBUG: All Static ===")
        for text in app.staticTexts.allElementsBoundByIndex {
            print("Static Text: '\(text.identifier)' - label: '\(text.label)' - exists: \(text.exists)")
        }
    }
    
    @MainActor
    func testAdd() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTesting")
        app.launch()
        
        XCTAssertTrue(waitForElement(app.buttons["addCardButton"]), "addCardButton did not appear")
        app.buttons["addCardButton"].tap()
                
        // Try finding by accessibility label since identifier is being overridden
        let nameField = app.textFields["Card name"]
        XCTAssertTrue(waitForElement(nameField), "nameTextField did not appear")
        
        let codeField = app.textFields["Card code"]
        
        let testName = "Test Name"
        let testCode = "Test Code"
        
        nameField.tap()
        nameField.typeText(testName)
        codeField.tap()
        codeField.typeText(testCode)
        
        app.buttons["saveCardButton"].tap()

        // Assert that we navigate to CardItemView with the new values
        XCTAssertTrue(waitForElement(app.staticTexts["Card name: \(testName)"]), "Card name '\(testName)' not displayed in CardItemView")
        XCTAssertTrue(waitForElement(app.staticTexts["Card code: \(testCode)"]), "Card code '\(testCode)' not displayed in CardItemView")
    }
}
