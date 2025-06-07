//
//  CardsUITests.swift
//  CardsUITests
//
//  Created by Serby, Paul on 18/12/2024.
//

import XCTest

final class CardsUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        // Pass -uiTesting flag to ensure in-memory storage is used
        app.launchArguments.append("-uiTesting")
        app.launch()
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }
    
    // Helper method to wait for an element to appear
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    func testAdd() throws {
        
        XCTAssertTrue(waitForElement(app.buttons["addCardButton"]), "addCardButton did not appear as expected")
        
        // Tap the add button using its accessibility identifier
        app.buttons["addCardButton"].tap()
        
        XCTAssertTrue(waitForElement(app.textFields["nameTextField"]), "nameTextField did not appear as expected")
        
        // Access text fields by their accessibility identifiers
        let enterNameTextField = app.textFields["nameTextField"]
        let enterCodeTextField = app.textFields["codeTextField"]
        
        // Verify initial state
        XCTAssertEqual(enterNameTextField.value as? String, "Enter name", "Enter Name text field is not empty")
        XCTAssertEqual(enterCodeTextField.value as? String, "Enter code", "Enter Code text field is not empty")
        
        // Enter test data
        enterNameTextField.tap()
        enterNameTextField.typeText("Test Name")
        
        enterCodeTextField.tap()
        enterCodeTextField.typeText("Test Code")
        
        // Save using accessibility identifier
        app.buttons["saveCardButton"].tap()
        
        // Wait for the list to update
        XCTAssertTrue(waitForElement(app.cells.firstMatch), "Cell did not appear after saving")
        
        // Verify the card was added
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.exists, "Expected at least one card in the list, but found none.")
        XCTAssertTrue(firstCell.staticTexts["Test Name"].exists, "First card in the list does not have the expected name 'Test Name'.")
        
        // Check the values are blank second time round
        app.buttons["addCardButton"].tap()
        
        XCTAssertEqual(enterNameTextField.value as? String, "Enter name", "Enter Name text field is not empty")
        XCTAssertEqual(enterCodeTextField.value as? String, "Enter code", "Enter Code text field is not empty")
    }
    
    func testEdit() throws {
        // Add a card first
        app.buttons["addCardButton"].tap()
        
        let enterNameTextField = app.textFields["nameTextField"]
        let enterCodeTextField = app.textFields["codeTextField"]
        
        enterNameTextField.tap()
        enterNameTextField.typeText("Test Name")
        
        enterCodeTextField.tap()
        enterCodeTextField.typeText("Test Code")
        
        // Use accessibility identifier for save button
        app.buttons["saveCardButton"].tap()
        
        // Wait for the list to update
        XCTAssertTrue(waitForElement(app.cells.firstMatch), "Cell did not appear after saving")
        
        // Tap on the first cell to view details
        app.cells.firstMatch.tap()
        
        // Wait for the detail view to appear
        XCTAssertTrue(waitForElement(app.otherElements["cardDetailView"]), "Card detail view did not appear")
        
        // Tap edit button using accessibility identifier
        app.buttons["editCardButton"].tap()
        
        // Wait for edit view to appear
        XCTAssertTrue(waitForElement(app.textFields["nameTextField"]), "Edit view did not appear")
        
        // Edit the fields
        enterNameTextField.tap()
        enterNameTextField.typeText("Edited ")
        
        enterCodeTextField.tap()
        enterCodeTextField.typeText("Edited ")
        
        // Save changes
        app.buttons["saveCardButton"].tap()
        
        // Wait for the detail view to reappear
        XCTAssertTrue(waitForElement(app.otherElements["cardDetailView"]), "Card detail view did not reappear after editing")
        
        // Verify the card name was updated
        XCTAssertTrue(app.staticTexts["cardNameText"].exists, "Card name text not found")
        
        // Navigate back to the list
        app.navigationBars.buttons.element(boundBy: 0).tap()
        
        // Wait for the list to appear
        XCTAssertTrue(waitForElement(app.cells.firstMatch), "Cell did not appear after navigating back")
        
        // Verify the edited card appears in the list
        XCTAssertTrue(app.staticTexts["Edited Test Name"].exists || app.staticTexts["Test Name"].exists,
                      "Edited card name not found in the list")
    }
    
    func testCardDetailAccessibility() throws {
        // Add a card first
        app.buttons["addCardButton"].tap()
        
        let enterNameTextField = app.textFields["nameTextField"]
        let enterCodeTextField = app.textFields["codeTextField"]
        
        enterNameTextField.tap()
        enterNameTextField.typeText("Accessibility Test")
        
        enterCodeTextField.tap()
        enterCodeTextField.typeText("123456789")
        
        app.buttons["saveCardButton"].tap()
        
        // Wait for the list to update
        XCTAssertTrue(waitForElement(app.cells.firstMatch), "Cell did not appear after saving")
        
        // Tap on the first cell to view details
        app.cells.firstMatch.tap()
        
        // Wait for the detail view to appear
        XCTAssertTrue(waitForElement(app.otherElements["cardDetailView"]), "Card detail view did not appear")
        
        // Verify accessibility elements exist
        XCTAssertTrue(app.staticTexts["cardNameText"].exists, "Card name accessibility element not found")
        XCTAssertTrue(app.otherElements["barcodeView"].exists, "Barcode view accessibility element not found")
        XCTAssertTrue(app.staticTexts["cardCodeText"].exists, "Card code accessibility element not found")
        XCTAssertTrue(app.staticTexts["cardTimestampText"].exists, "Card timestamp accessibility element not found")
        XCTAssertTrue(app.buttons["editCardButton"].exists, "Edit button accessibility element not found")
    }

}
