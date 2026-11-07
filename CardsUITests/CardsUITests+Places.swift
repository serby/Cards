import XCTest

/// Adding and changing a card's places. In CardsUITests, so
/// CardsRightToLeftUITests runs them right to left too.
extension CardsUITests {
    /// Tapping a place in the form opens it in the picker to change, and Save
    /// puts the change in the form (PLACE-8).
    @MainActor
    func testEditAPlace() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-screenshotSeed"]
        app.launch()

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
