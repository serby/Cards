import XCTest

/// A card's screen, its places and Settings: adding where you are, copying
/// the code, the location picker and the switches and Distances menu
/// (PLACE-4, PLACE-8, PLACE-2, SET-3, SET-4). `CardPlacesAndSettingsRightToLeftUITests`
/// runs it again in Arabic, right to left.
class CardPlacesAndSettingsUITests: CardsUITestCase {
    /// Adding where you are from the card screen saves it to the card, named
    /// for the place under the pin, and the card then reads as "here" and still
    /// offers to add another (PLACE-4, PLACE-10).
    @MainActor
    func testAddCurrentLocationFromCard() throws {
        let app = launchWithSeededCards()

        // Honeycomb Rewards has no locations; the seed puts the user at Notting Hill Gate.
        let honeycomb = app.tile(SeededCard.honeycomb)
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
        // Still there inside the new place, to add another (PLACE-4).
        XCTAssertTrue(addHere.exists)
    }

    /// The copy button says it copied, then goes back to offering to copy.
    @MainActor
    func testCopyCardCode() throws {
        let app = launchWithSeededCards()

        let honeycomb = app.tile(SeededCard.honeycomb)
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.tap()

        // The clipboard itself is not read: that asks for permission to paste.
        let copy = app.buttons["copyCodeButton"]
        XCTAssertTrue(waitForElement(copy))
        let offer = copy.label
        if Self.isEnglish {
            XCTAssertEqual(offer, "Copy card code")
        }
        copy.tap()
        XCTAssertTrue(copy.matches(NSPredicate(format: "label != %@", offer), within: 2), "The button did not say it copied")
        if Self.isEnglish {
            XCTAssertEqual(copy.label, "Copied")
        }
        XCTAssertTrue(waitForLabel(copy, offer, timeout: 4), "The button did not go back to offering to copy")
    }

    @MainActor
    func testArrivalNotificationsSwitch() throws {
        let app = XCUIApplication.forTesting(Self.variantArguments)
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
        let app = XCUIApplication.forTesting(Self.variantArguments)
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
    /// In English the tile names the units, spelt the British way; in another
    /// language, whose words and digits are its own, the tile reads
    /// differently in miles and in kilometres.
    @MainActor
    func testDistancesFollowTheSetting() throws {
        // Not pinned, as launchWithSeededCards does, so the picker can change it.
        let app = XCUIApplication.forTesting(
            ["-screenshotSeed", "-cardSortOrder", "custom", "-showsCardWhereYouAre", "NO"] + Self.variantArguments
        )
        app.launch()
        let localRoast = app.tile(SeededCard.localRoast)
        XCTAssertTrue(waitForElement(localRoast))
        // The place's name is user content, the same in any language.
        let place = "Local Roast Portobello"

        choose(app, distanceUnits: "miles")
        app.cardsTab.tap()
        if Self.isEnglish {
            XCTAssertTrue(waitForLabel(localRoast, containing: " yards from \(place)"), localRoast.label)
        }
        XCTAssertTrue(waitForLabel(localRoast, containing: place), localRoast.label)
        let inMiles = localRoast.label

        choose(app, distanceUnits: "kilometres")
        app.cardsTab.tap()
        if Self.isEnglish {
            XCTAssertTrue(waitForLabel(localRoast, containing: " metres from \(place)"), localRoast.label)
        }
        XCTAssertTrue(
            localRoast.matches(NSPredicate(format: "label != %@ AND label CONTAINS %@", inMiles, place)),
            "The tile reads the same in kilometres as in miles: \(localRoast.label)"
        )

        choose(app, distanceUnits: "automatic")
    }

    /// Tapping a place in the form opens it in the picker to change, and Save
    /// puts the change in the form (PLACE-8).
    @MainActor
    func testEditAPlace() throws {
        let app = launchWithSeededCards()
        app.openCard(SeededCard.joesMarket)
        app.buttons["editCardButton"].tap()

        // Both places on screen, the second below the first, so the form never
        // has to scroll to check the second afterwards: the form loads only the
        // rows on screen, and when Notting Hill counted as hittable at the foot
        // of the screen the form did not scroll and Kensington was not there.
        let nottingHill = app.buttons["locationRow_Joe's Market Notting Hill"]
        let kensington = app.buttons["locationRow_Joe's Market Kensington"]
        XCTAssertTrue(app.reveal(kensington), "Could not scroll to the card's places")
        nottingHill.tap()

        // Save, where Add Location has Add, shows it is the Edit Location sheet.
        XCTAssertTrue(waitForElement(app.buttons["saveLocationButton"]), "Edit Location did not open")
        let nameField = app.textFields["locationNameField"]
        XCTAssertEqual(nameField.value as? String, "Joe's Market Notting Hill")
        // Put the cursor at the end, then replace the area. The name reads left
        // to right, so its end is on its right: left to right that is empty
        // space, and right to left the name sits against the field's right
        // edge, where a tap at 95% of the width landed inside "Hill" on iOS 18.
        // A tap just inside that edge lands after the name either way round.
        // Typing an apostrophe could come out curly, so the shop's name is left
        // as it is.
        nameField.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -1, dy: 0)).tap()
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Notting Hill".count) + "Holland Park")
        app.buttons["saveLocationButton"].tap()

        XCTAssertTrue(
            waitForElement(app.buttons["locationRow_Joe's Market Holland Park"]),
            "The renamed place is not in the form"
        )
        XCTAssertFalse(app.buttons["locationRow_Joe's Market Notting Hill"].exists)
        XCTAssertTrue(kensington.exists, "The other place is left as it was")
    }

    /// Typing in the picker's search field suggests places; choosing one moves
    /// the map there and names the place after it (PLACE-2, PLACE-10).
    @MainActor
    func testFindAPlaceBySearch() throws {
        let app = launchWithSeededCards()

        let honeycomb = app.tile(SeededCard.honeycomb)
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

    /// Settings > Maps offers Apple Maps and Google Maps, Apple Maps until
    /// another is chosen (SET-5). The choice is kept, so the test ends on Apple Maps.
    @MainActor
    func testChooseTheMapsApp() throws {
        let app = XCUIApplication.forTesting(
            ["-screenshotSeed", "-cardSortOrder", "custom", "-showsCardWhereYouAre", "NO"] + Self.variantArguments
        )
        app.launch()
        app.settingsTab.tap()
        let picker = app.buttons["mapsAppPicker"]
        XCTAssertTrue(waitForElement(picker))
        XCTAssertTrue(app.reveal(picker), "The Maps menu is not clear of the tab bar")
        for (choice, name) in [("googleMaps", "Google Maps"), ("appleMaps", "Apple Maps")] {
            let shown = choose(app, choice, from: picker)
            if Self.isEnglish {
                XCTAssertEqual(shown, name)
            }
        }
    }

    /// Picks `distanceUnits`, the units' stored value (`DistanceUnits`), in
    /// Settings > Distances.
    @MainActor
    private func choose(_ app: XCUIApplication, distanceUnits: String) {
        app.settingsTab.tap()
        let picker = app.buttons["distanceUnitsPicker"]
        XCTAssertTrue(waitForElement(picker))
        XCTAssertTrue(app.reveal(picker), "The Distances menu is not clear of the tab bar")
        choose(app, distanceUnits, from: picker)
    }

    /// Opens the Settings menu `picker` and picks `choice`, its stored value,
    /// by the item's identifier (`SettingsListView.choiceMenu`), then checks
    /// the row shows the item's own words as its choice, whatever the
    /// language. Returns those words.
    @MainActor
    @discardableResult
    private func choose(_ app: XCUIApplication, _ choice: String, from picker: XCUIElement) -> String {
        picker.tap()
        let option = app.buttons["\(picker.identifier)_\(choice)"]
        XCTAssertTrue(waitForElement(option), "The menu does not offer \(choice)")
        let name = option.label
        option.tap()
        // The row shows the choice as its value, or in its label.
        let chosen = NSPredicate(format: "label CONTAINS %@ OR value BEGINSWITH %@", name, name)
        XCTAssertTrue(picker.matches(chosen), "The menu does not show \(name): \(picker.debugDescription)")
        return name
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 5) -> Bool {
        element.matches(NSPredicate(format: "label CONTAINS %@", text), within: timeout)
    }
}

/// Every test again in Arabic, right to left (`CardsUITestCase.rightToLeft`).
final class CardPlacesAndSettingsRightToLeftUITests: CardPlacesAndSettingsUITests {
    override static var variantArguments: [String] { rightToLeft }
    override static var isRightToLeft: Bool { true }
}
