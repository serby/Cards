import XCTest

/// The edit form: opening it from a tile, deleting a card from it and choosing
/// its icon (CARD-5, CARD-6, CARD-10, CARD-12).
final class CardEditFormUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Edit in a tile's long-press menu opens the card's form, with the keyboard
    /// down, and Back goes to the card's screen (CARD-5, CARD-10).
    @MainActor
    func testEditFromTheLongPressMenu() throws {
        let app = launchWithSeededCards()
        let honeycomb = tile(app, "Honeycomb Rewards")
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.press(forDuration: 1)

        let edit = app.buttons["editCardMenuItem"]
        XCTAssertTrue(waitForElement(edit))
        edit.tap()

        let nameField = app.textFields["nameTextField"]
        XCTAssertTrue(waitForElement(nameField))
        XCTAssertEqual(nameField.value as? String, "Honeycomb Rewards")
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2), "The form should open with the keyboard down")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(waitForElement(app.buttons["editCardButton"]), "Back should go to the card's screen")
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

    /// An icon chosen in the grid is saved with the card and is there when the
    /// form opens again (CARD-12).
    @MainActor
    func testChooseAnIcon() throws {
        let app = XCUIApplication.forTesting(["-screenshotSeed"])
        app.launch()

        let honeycomb = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Honeycomb Rewards")).firstMatch
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.tap()
        app.buttons["editCardButton"].tap()

        let iconRow = app.buttons["iconRow"]
        for _ in 0..<3 where !(iconRow.exists && iconRow.isHittable) {
            app.descendants(matching: .any)["editCardForm"].firstMatch.swipeUp()
        }
        XCTAssertEqual(iconRow.value as? String, "None")
        iconRow.tap()
        let basket = app.buttons["cardIcon_basket.fill"]
        XCTAssertTrue(waitForElement(basket))
        basket.tap()
        XCTAssertTrue(basket.waitForNonExistence(timeout: 3), "Choosing an icon closes the grid")
        XCTAssertEqual(iconRow.value as? String, "Basket")

        app.buttons["saveCardButton"].tap()
        XCTAssertTrue(waitForElement(app.buttons["editCardButton"]))
        app.buttons["editCardButton"].tap()
        for _ in 0..<3 where !(iconRow.exists && iconRow.isHittable) {
            app.descendants(matching: .any)["editCardForm"].firstMatch.swipeUp()
        }
        XCTAssertEqual(iconRow.value as? String, "Basket")
    }

    /// The grid opens at the card's icon, even one in its last group (CARD-12).
    @MainActor
    func testTheIconGridOpensAtTheChosenIcon() throws {
        let app = XCUIApplication.forTesting(["-screenshotSeed"])
        app.launch()

        let honeycomb = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Honeycomb Rewards")).firstMatch
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.tap()
        app.buttons["editCardButton"].tap()

        let iconRow = app.buttons["iconRow"]
        for _ in 0..<3 where !(iconRow.exists && iconRow.isHittable) {
            app.descendants(matching: .any)["editCardForm"].firstMatch.swipeUp()
        }
        iconRow.tap()
        // Far below the sheet's first height: drag the sheet open and scroll to it.
        let pushchair = app.buttons["cardIcon_stroller.fill"]
        let low = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        let high = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        for _ in 0..<10 where !(pushchair.exists && pushchair.isHittable) {
            low.press(forDuration: 0.05, thenDragTo: high)
        }
        pushchair.tap()
        XCTAssertTrue(pushchair.waitForNonExistence(timeout: 3), "Choosing an icon closes the grid")
        XCTAssertEqual(iconRow.value as? String, "Pushchair")

        iconRow.tap()
        XCTAssertTrue(waitForElement(pushchair))
        XCTAssertTrue(pushchair.isHittable, "The grid opens at the chosen icon")
        let basket = app.buttons["cardIcon_basket.fill"]
        XCTAssertFalse(basket.exists && basket.isHittable, "The grid is not at its top")
    }
}
