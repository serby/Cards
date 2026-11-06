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

    /// Adding where you are from the card screen saves it to the card, named
    /// for the place under the pin, and the card then reads as "here" and stops
    /// offering to add it again (PLACE-4, PLACE-10).
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
        // UI tests search the made-up places, which put Joe's Market beside the seed's location.
        XCTAssertTrue(waitForValue(app.textFields["locationNameField"], "Joe's Market Notting Hill", timeout: 10))
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

    /// The Distances choice in Settings decides the units the tiles read their
    /// distances in (SET-4). The choice is kept, so the test ends on Automatic.
    @MainActor
    func testDistancesFollowTheSetting() throws {
        let app = XCUIApplication()
        // Not pinned, as launchWithSeededCards does, so the picker can change it.
        app.launchArguments += ["-uiTesting", "-screenshotSeed", "-cardSortOrder", "custom", "-showsCardWhereYouAre", "NO"]
        app.launch()
        dismissNotificationPrompt()
        let localRoast = tile(app, "Local Roast Coffee")
        XCTAssertTrue(waitForElement(localRoast))

        choose(app, distanceUnits: "Miles")
        app.tabBars.buttons["Cards"].tap()
        XCTAssertTrue(waitForLabel(localRoast, containing: " yd from Local Roast Portobello"), localRoast.label)

        choose(app, distanceUnits: "Kilometres")
        app.tabBars.buttons["Cards"].tap()
        XCTAssertTrue(waitForLabel(localRoast, containing: " m from Local Roast Portobello"), localRoast.label)

        choose(app, distanceUnits: "Automatic", startingWith: true)
    }

    /// Picks `distanceUnits` in Settings > Distances. Automatic is listed with
    /// what it means, as "Automatic (Miles)", so it is found by how it starts.
    @MainActor
    private func choose(_ app: XCUIApplication, distanceUnits: String, startingWith: Bool = false) {
        app.tabBars.buttons["Settings"].tap()
        let picker = app.buttons["distanceUnitsPicker"]
        XCTAssertTrue(waitForElement(picker))
        picker.tap()
        let option = startingWith
            ? app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", distanceUnits)).firstMatch
            : app.buttons[distanceUnits]
        XCTAssertTrue(waitForElement(option))
        option.tap()
        // The row shows the choice as its value, or in its label.
        let chosen = NSPredicate(format: "label CONTAINS %@ OR value BEGINSWITH %@", distanceUnits, distanceUnits)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: chosen, evaluatedWith: picker)], timeout: 5), .completed)
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: timeout) == .completed
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

    @MainActor
    private func choose(_ app: XCUIApplication, sortOrder: String) {
        app.buttons["sortMenu"].tap()
        let option = app.buttons[sortOrder]
        XCTAssertTrue(waitForElement(option))
        option.tap()
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

    /// Typing in the picker's search field suggests places; choosing one moves
    /// the map there and names the place after it (PLACE-2, PLACE-10).
    @MainActor
    func testFindAPlaceBySearch() throws {
        let app = launchWithSeededCards()

        let honeycomb = tile(app, "Honeycomb Rewards")
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.tap()
        app.buttons["addCurrentLocationButton"].tap()
        let search = app.textFields["placeSearchField"]
        XCTAssertTrue(waitForElement(search))
        search.tap()
        search.typeText("Local Roast")
        let suggestion = app.buttons["placeSuggestion_Local Roast Notting Hill"]
        XCTAssertTrue(waitForElement(suggestion))
        XCTAssertTrue(app.buttons["placeSuggestion_Local Roast Portobello"].exists)
        suggestion.tap()

        XCTAssertTrue(waitForValue(app.textFields["locationNameField"], "Local Roast Notting Hill"))
        app.buttons["addLocationButton"].tap()
        let proximity = app.descendants(matching: .any)["cardProximityText"].firstMatch
        XCTAssertTrue(waitForElement(proximity))
        XCTAssertTrue(proximity.label.contains("Local Roast Notting Hill"), proximity.label)
    }
}
