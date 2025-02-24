//
//  CardsUITestsLaunchTests.swift
//  CardsUITests
//
//  Created by Serby, Paul on 18/12/2024.
//

import XCTest
@testable import Cards

final class CardsUITestsLaunchTests: XCTestCase {
    
    let app = XCUIApplication()
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {

        // Pass -uiTesting flag to ensure in-memory storage is used
        app.launchArguments.append("-uiTesting")
        app.launch()

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

    }

    func testAdd() throws {
        
        app.buttons["addCardButton"].tap()
        
        let enterNameTextField = app.textFields["Enter name"]
        XCTAssertEqual(enterNameTextField.value as? String, "Enter name", "Enter Name text field is not empty")
        
        let enterCodeTextField = app.textFields["Enter code"]
        XCTAssertEqual(enterCodeTextField.value as? String, "Enter code", "Enter Code text field is not empty")
        
        enterNameTextField.tap()
        enterNameTextField.typeText("Test Name")
        
        enterCodeTextField.tap()
        enterCodeTextField.typeText("Test Code")
        app.buttons["saveCardButton"].tap()
        
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.exists, "Expected at least one card in the list, but found none.")
        XCTAssertTrue(firstCell.staticTexts["Test Name"].exists, "First card in the list does not have the expected name 'Test Name'.")
        
        // Check the values are blank second time round
        app.buttons["addCardButton"].tap()
        
        XCTAssertEqual(enterNameTextField.value as? String, "Enter name", "Enter Name text field is not empty")
        
        XCTAssertEqual(enterCodeTextField.value as? String, "Enter code", "Enter Code text field is not empty")
    }
    
    func testEdit() throws {
        
        app.buttons["addCardButton"].tap()
        
        let enterNameTextField = app.textFields["Enter name"]
        let enterCodeTextField = app.textFields["Enter code"]
        enterNameTextField.tap()
        enterNameTextField.typeText("Test Name")
        
        enterCodeTextField.tap()
        enterCodeTextField.typeText("Test Code")
        app.navigationBars["Add Card"]/*@START_MENU_TOKEN@*/.buttons["Save"]/*[[".otherElements[\"Save\"].buttons[\"Save\"]",".buttons[\"Save\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        let collectionViewsQuery = app.collectionViews
        collectionViewsQuery.buttons["Test Name"].tap()
        app.buttons["editCardButton"].tap()
        
        enterNameTextField.tap()
        enterNameTextField.typeText("Edited ")
        
        enterCodeTextField.tap()
        enterCodeTextField.typeText("Edited ")
        
        app.buttons["saveCardButton"].tap()
        
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.exists, "Expected at least one card in the list, but found none.")
        XCTAssertTrue(firstCell.staticTexts["Test Name"].exists, "First card in the list does not have the expected name 'Test Name'.")
    }
}
