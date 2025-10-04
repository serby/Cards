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
    }
    
    @MainActor
    func testAdd() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTesting")
        app.launch()
        
        XCTAssertTrue(waitForElement(app.buttons["addCardButton"]), "addCardButton did not appear")
        app.buttons["addCardButton"].tap()
        
        // Wait longer for sheet to present
        sleep(3)
        
        // Try finding by accessibility label since identifier is being overridden
        let nameField = app.textFields["Card name"]
        XCTAssertTrue(waitForElement(nameField, timeout: 10), "nameTextField did not appear")
        
        let codeField = app.textFields["Card code"]
        
        nameField.tap()
        nameField.typeText("Test Name")
        codeField.tap()
        codeField.typeText("Test Code")
        
        app.buttons["saveCardButton"].tap()
        
        XCTAssertTrue(waitForElement(app.cells.firstMatch), "Cell did not appear after saving")
    }
}
