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

    /// Adding a card offers a photo or a file of its barcode under the camera;
    /// editing one offers neither (CARD-13). The pickers are the system's, so
    /// the test stops at the buttons.
    @MainActor
    func testAddFormOffersAPhotoOrAFile() throws {
        let app = launchWithSeededCards()
        XCTAssertTrue(waitForElement(app.buttons["addCardButton"]))
        app.buttons["addCardButton"].tap()

        XCTAssertTrue(waitForElement(app.buttons["choosePhotoButton"]), "Choose Photo did not appear")
        XCTAssertTrue(app.buttons["chooseBarcodeFileButton"].exists, "Choose File did not appear")
        XCTAssertTrue(app.staticTexts["Read the barcode in a screenshot, a photo or a PDF, such as an e-ticket."].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let honeycomb = tile(app, "Honeycomb Rewards")
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.tap()
        app.buttons["editCardButton"].tap()
        XCTAssertTrue(waitForElement(app.descendants(matching: .any)["editCardForm"].firstMatch))
        XCTAssertFalse(app.buttons["choosePhotoButton"].exists, "Editing a card should not offer Choose Photo")
        XCTAssertFalse(app.buttons["chooseBarcodeFileButton"].exists, "Editing a card should not offer Choose File")
    }

    /// Adding where you are from the card screen saves it to the card, which then
    /// reads as "here" and stops offering to add it again.
    @MainActor
    func testAddCurrentLocationFromCard() throws {
        let app = launchWithSeededCards()

        // Honeycomb Rewards has no locations; the seed puts the user at Notting Hill Gate.
        let honeycomb = tile(app, "Honeycomb Rewards")
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.tap()

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
        let app = launchWithSeededCards()

        let honeycomb = tile(app, "Honeycomb Rewards")
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.tap()

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

    @MainActor
    func testShowCardWhereIAmSwitch() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTesting")
        app.launch()
        app.tabBars.buttons["Settings"].tap()

        let toggle = app.switches["showsCardWhereYouAreToggle"]
        XCTAssertTrue(waitForElement(toggle))
        let before = toggle.value as? String
        toggle.switches.firstMatch.tap()
        XCTAssertNotEqual(toggle.value as? String, before)
        // The setting outlives the app, so put it back for the next test.
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, before)
    }

    /// Typing in the search field narrows the grid to the names that match (CARD-11).
    @MainActor
    func testSearchFiltersCards() throws {
        let app = launchWithSeededCards()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(waitForElement(search))
        search.tap()
        search.typeText("hon")
        XCTAssertTrue(waitForElement(tile(app, "Honeycomb Rewards")))
        XCTAssertTrue(tile(app, "Joe's Market").waitForNonExistence(timeout: 3))

        search.typeText("zzz")
        XCTAssertTrue(waitForElement(app.staticTexts["No Cards Match"]))
    }

    /// A long press on a tile offers Delete, which removes the card at once (CARD-6, CARD-10).
    @MainActor
    func testDeleteFromTheLongPressMenu() throws {
        let app = launchWithSeededCards()
        let honeycomb = tile(app, "Honeycomb Rewards")
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.press(forDuration: 1)

        let delete = app.buttons["Delete"]
        XCTAssertTrue(waitForElement(delete))
        delete.tap()
        XCTAssertTrue(honeycomb.waitForNonExistence(timeout: 3))
        XCTAssertTrue(tile(app, "Nordic Nest Home").exists)
    }

    /// In custom order, a tile dropped on another takes its place (CARD-7, CARD-10).
    @MainActor
    func testDragATileToReorder() throws {
        let app = launchWithSeededCards()
        let honeycomb = tile(app, "Honeycomb Rewards")
        let joesMarket = tile(app, "Joe's Market")
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.press(forDuration: 1, thenDragTo: joesMarket)

        // Honeycomb Rewards is now first, at the top left, and Joe's Market moved along beside it.
        let moved = NSPredicate { _, _ in
            honeycomb.frame.minX < joesMarket.frame.minX && abs(honeycomb.frame.minY - joesMarket.frame.minY) < 1
        }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: moved, evaluatedWith: nil)], timeout: 5), .completed)
    }

    /// Location order puts the cards with places first and Honeycomb Rewards, which has
    /// none, last; custom order puts it back (CARD-11). The choice is kept, so
    /// the test ends on custom order.
    @MainActor
    func testSortMenuChangesTheOrder() throws {
        let app = XCUIApplication()
        // Not pinned, as launchWithSeededCards does, so the menu can change it.
        app.launchArguments += ["-uiTesting", "-screenshotSeed", "-showsCardWhereYouAre", "NO"]
        app.launch()
        dismissNotificationPrompt()
        let honeycomb = tile(app, "Honeycomb Rewards")
        let nordicNest = tile(app, "Nordic Nest Home")
        XCTAssertTrue(waitForElement(honeycomb))

        choose(app, sortOrder: "Location")
        let honeycombLast = NSPredicate { _, _ in honeycomb.frame.minY > nordicNest.frame.minY || honeycomb.frame.minX > nordicNest.frame.minX }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: honeycombLast, evaluatedWith: nil)], timeout: 5), .completed)

        choose(app, sortOrder: "Custom Order")
        let honeycombFirst = NSPredicate { _, _ in
            abs(honeycomb.frame.minY - nordicNest.frame.minY) < 1 && honeycomb.frame.minX < nordicNest.frame.minX
        }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: honeycombFirst, evaluatedWith: nil)], timeout: 5), .completed)
    }

    /// With Show Card Where I Am on, the card for where you are is shown in
    /// full above the grid, and opens when tapped (SET-3).
    @MainActor
    func testCardWhereYouAre() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-screenshotSeed", "-cardSortOrder", "custom", "-showsCardWhereYouAre", "YES"]
        app.launch()
        dismissNotificationPrompt()

        // The seed puts the user inside Joe's Market Notting Hill.
        let cardHere = app.buttons["cardWhereYouAre"]
        XCTAssertTrue(waitForElement(cardHere))
        XCTAssertEqual(cardHere.label, "Joe's Market, You're at Joe's Market Notting Hill")
        XCTAssertTrue(tile(app, "Local Roast Coffee").exists)
        cardHere.tap()
        XCTAssertTrue(waitForElement(app.staticTexts["Card name: Joe's Market"]))
    }

    /// Launches with the six screenshot cards, in custom order and without the
    /// card for where you are, whatever an earlier run left in those settings.
    @MainActor
    private func launchWithSeededCards() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-screenshotSeed", "-cardSortOrder", "custom", "-showsCardWhereYouAre", "NO"]
        app.launch()
        dismissNotificationPrompt()
        return app
    }

    /// A card's tile. Its label starts with the card name and goes on to say how
    /// far away the card is.
    @MainActor
    private func tile(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    @MainActor
    private func choose(_ app: XCUIApplication, sortOrder: String) {
        app.buttons["sortMenu"].tap()
        let option = app.buttons[sortOrder]
        XCTAssertTrue(waitForElement(option))
        option.tap()
    }

    /// Delete Card at the foot of the edit form asks first, deletes the card and
    /// goes back to the list (CARD-5, CARD-6).
    @MainActor
    func testDeleteFromTheEditForm() throws {
        let app = launchWithSeededCards()
        let honeycomb = tile(app, "Honeycomb Rewards")
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.tap()
        app.buttons["editCardButton"].tap()

        let deleteRow = app.buttons["deleteCardButton"]
        for _ in 0..<4 where !(deleteRow.exists && deleteRow.isHittable) {
            app.descendants(matching: .any)["editCardForm"].firstMatch.swipeUp()
        }
        deleteRow.tap()
        // The dialog's own Delete Card, not the row that opened it.
        let confirm = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Delete Card", "deleteCardButton")).firstMatch
        XCTAssertTrue(waitForElement(confirm))
        confirm.tap()

        XCTAssertTrue(waitForElement(app.buttons["addCardButton"]))
        XCTAssertTrue(tile(app, "Honeycomb Rewards").waitForNonExistence(timeout: 3))
        XCTAssertTrue(tile(app, "Nordic Nest Home").exists)
    }

    /// A symbol chosen in the grid is saved with the card and is there when the
    /// form opens again (CARD-12).
    @MainActor
    func testChooseASymbol() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-screenshotSeed"]
        app.launch()
        dismissNotificationPrompt()

        let honeycomb = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Honeycomb Rewards")).firstMatch
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.tap()
        app.buttons["editCardButton"].tap()

        let symbolRow = app.buttons["symbolRow"]
        for _ in 0..<3 where !(symbolRow.exists && symbolRow.isHittable) {
            app.descendants(matching: .any)["editCardForm"].firstMatch.swipeUp()
        }
        XCTAssertEqual(symbolRow.value as? String, "None")
        symbolRow.tap()
        let basket = app.buttons["cardSymbol_basket.fill"]
        XCTAssertTrue(waitForElement(basket))
        basket.tap()
        XCTAssertTrue(basket.waitForNonExistence(timeout: 3), "Choosing a symbol closes the grid")
        XCTAssertEqual(symbolRow.value as? String, "Basket")

        app.buttons["saveCardButton"].tap()
        XCTAssertTrue(waitForElement(app.buttons["editCardButton"]))
        app.buttons["editCardButton"].tap()
        for _ in 0..<3 where !(symbolRow.exists && symbolRow.isHittable) {
            app.descendants(matching: .any)["editCardForm"].firstMatch.swipeUp()
        }
        XCTAssertEqual(symbolRow.value as? String, "Basket")
    }

    /// Tapping a place in the form opens it in the picker to change, and Save
    /// puts the change in the form (PLACE-8).
    @MainActor
    func testEditAPlace() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-screenshotSeed"]
        app.launch()
        dismissNotificationPrompt()

        let joesMarket = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Joe's Market")).firstMatch
        XCTAssertTrue(waitForElement(joesMarket))
        joesMarket.tap()
        app.buttons["editCardButton"].tap()

        let form = app.descendants(matching: .any)["editCardForm"].firstMatch
        let nottingHill = app.buttons["locationRow_Joe's Market Notting Hill"]
        for _ in 0..<4 where !(nottingHill.exists && nottingHill.isHittable) {
            form.swipeUp()
        }
        nottingHill.tap()

        XCTAssertTrue(waitForElement(app.navigationBars["Edit Location"]))
        let nameField = app.textFields["locationNameField"]
        XCTAssertEqual(nameField.value as? String, "Joe's Market Notting Hill")
        // Put the cursor at the end, then replace the area. Typing an apostrophe
        // could come out curly, so the shop's name is left as it is.
        nameField.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Notting Hill".count) + "Holland Park")
        app.buttons["saveLocationButton"].tap()

        XCTAssertTrue(waitForElement(app.buttons["locationRow_Joe's Market Holland Park"]))
        XCTAssertFalse(app.buttons["locationRow_Joe's Market Notting Hill"].exists)
        XCTAssertTrue(app.buttons["locationRow_Joe's Market Kensington"].exists, "The other place is left as it was")
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
