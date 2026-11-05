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
    
    /// Waits for a label to change. A predicate re-reads the element; `wait(for:toEqual:)` missed the change.
    @MainActor
    func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        return XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: timeout) == .completed
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

    /// Adding where you are from the card screen saves it to the card, which then
    /// reads as "here" and stops offering to add it again.
    @MainActor
    func testAddCurrentLocationFromCard() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-screenshotSeed"]
        app.launch()
        dismissNotificationPrompt()

        // Nectar has no locations; the seed puts the user at Notting Hill Gate.
        let nectar = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Nectar")).firstMatch
        XCTAssertTrue(waitForElement(nectar))
        nectar.tap()

        let addHere = app.buttons["addCurrentLocationButton"]
        XCTAssertTrue(waitForElement(addHere))
        addHere.tap()
        XCTAssertTrue(waitForElement(app.descendants(matching: .any)["locationPickerMap"].firstMatch))
        app.buttons["addLocationButton"].tap()

        XCTAssertTrue(waitForElement(app.descendants(matching: .any)["cardProximityText"].firstMatch))
        XCTAssertTrue(addHere.waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testCopyCardCode() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-screenshotSeed"]
        app.launch()
        dismissNotificationPrompt()

        let nectar = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Nectar")).firstMatch
        XCTAssertTrue(waitForElement(nectar))
        nectar.tap()

        // The clipboard itself is not read: that asks for permission to paste.
        let copy = app.buttons["copyCodeButton"]
        XCTAssertTrue(waitForElement(copy))
        XCTAssertEqual(copy.label, "Copy card code")
        copy.tap()
        XCTAssertTrue(waitForLabel(copy, "Copied", timeout: 2))
        XCTAssertTrue(waitForLabel(copy, "Copy card code", timeout: 4))
    }

    @MainActor
    func testArrivalNotificationsSwitch() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTesting")
        app.launch()
        app.tabBars.buttons["Settings"].tap()

        let toggle = app.switches["arrivalNotificationsToggle"]
        XCTAssertTrue(waitForElement(toggle))
        let before = toggle.value as? String
        toggle.switches.firstMatch.tap()
        XCTAssertNotEqual(toggle.value as? String, before)
        // The setting outlives the app, so put it back for the next test.
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, before)
    }

    /// Cards with locations ask for notifications once; answer so the alert
    /// does not cover the app.
    @MainActor
    private func dismissNotificationPrompt() {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 5) {
            alert.buttons.element(boundBy: 1).tap()
        }
    }
}
