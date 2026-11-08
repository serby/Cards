import XCTest

/// A card's screen, its places and Settings: adding where you are, copying
/// the code, the location picker and the switches and Distances menu
/// (PLACE-4, PLACE-8, PLACE-2, SET-3, SET-4). `CardPlacesAndSettingsRightToLeftUITests`
/// runs it again right to left.
class CardPlacesAndSettingsUITests: CardsUITestCase {
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
        XCTAssertTrue(addHere.disappears(within: 3))
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
        let app = XCUIApplication.forTesting()
        app.launch()
        app.settingsTab.tap()

        let toggle = app.switches["arrivalNotificationsToggle"]
        XCTAssertTrue(waitForElement(toggle))
        let before = try XCTUnwrap(toggle.value as? String)
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(toggle.matches(NSPredicate(format: "value != %@", before)), "The switch did not change")
        // The setting outlives the app, so put it back for the next test.
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(toggle.matches(NSPredicate(format: "value == %@", before)), "The switch did not change back")
    }

    @MainActor
    func testShowCardWhereIAmSwitch() throws {
        let app = XCUIApplication.forTesting()
        app.launch()
        app.settingsTab.tap()

        let toggle = app.switches["showsCardWhereYouAreToggle"]
        XCTAssertTrue(waitForElement(toggle))
        let before = try XCTUnwrap(toggle.value as? String)
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(toggle.matches(NSPredicate(format: "value != %@", before)), "The switch did not change")
        // The setting outlives the app, so put it back for the next test.
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(toggle.matches(NSPredicate(format: "value == %@", before)), "The switch did not change back")
    }

    /// The Distances choice in Settings decides the units the tiles read their
    /// distances in (SET-4). The choice is kept, so the test ends on Automatic.
    @MainActor
    func testDistancesFollowTheSetting() throws {
        // Not pinned, as launchWithSeededCards does, so the picker can change it.
        let app = XCUIApplication.forTesting(["-screenshotSeed", "-cardSortOrder", "custom", "-showsCardWhereYouAre", "NO"])
        app.launch()
        let localRoast = tile(app, "Local Roast Coffee")
        XCTAssertTrue(waitForElement(localRoast))

        choose(app, distanceUnits: "Miles")
        app.cardsTab.tap()
        XCTAssertTrue(waitForLabel(localRoast, containing: " yards from Local Roast Portobello"), localRoast.label)

        choose(app, distanceUnits: "Kilometres")
        app.cardsTab.tap()
        XCTAssertTrue(waitForLabel(localRoast, containing: " metres from Local Roast Portobello"), localRoast.label)

        choose(app, distanceUnits: "Automatic", startingWith: true)
    }

    /// Tapping a place in the form opens it in the picker to change, and Save
    /// puts the change in the form (PLACE-8).
    @MainActor
    func testEditAPlace() throws {
        let app = XCUIApplication.forTesting(["-screenshotSeed"])
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
        // With one place, the top panel's place opens it in Maps (PLACE-6).
        XCTAssertTrue([.button, .link].contains(proximity.elementType), "The place is a \(proximity.elementType), not a link")
    }

    /// Picks `distanceUnits` in Settings > Distances. Automatic is listed with
    /// what it means, as "Automatic (Miles)", so it is found by how it starts.
    @MainActor
    private func choose(_ app: XCUIApplication, distanceUnits: String, startingWith: Bool = false) {
        app.settingsTab.tap()
        let picker = app.buttons["distanceUnitsPicker"]
        XCTAssertTrue(waitForElement(picker))
        XCTAssertTrue(app.reveal(picker), "The Distances menu is not clear of the tab bar")
        picker.tap()
        let option = startingWith
            ? app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", distanceUnits)).firstMatch
            : app.buttons[distanceUnits]
        XCTAssertTrue(waitForElement(option))
        option.tap()
        // The row shows the choice as its value, or in its label.
        let chosen = NSPredicate(format: "label CONTAINS %@ OR value BEGINSWITH %@", distanceUnits, distanceUnits)
        XCTAssertTrue(picker.matches(chosen))
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 5) -> Bool {
        element.matches(NSPredicate(format: "label CONTAINS %@", text), within: timeout)
    }
}

/// Every test again right to left (`CardsUITestCase.rightToLeft`).
final class CardPlacesAndSettingsRightToLeftUITests: CardPlacesAndSettingsUITests {
    override static var variantArguments: [String] { rightToLeft }
    override static var isRightToLeft: Bool { true }
}
