import XCTest

/// The edit form: opening it from a tile, deleting a card from it, choosing
/// its icon and writing its notes (CARD-5, CARD-6, CARD-10, CARD-12, CARD-14).
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
        XCTAssertFalse(app.keyboards.firstMatch.appears(within: 2), "The form should open with the keyboard down")

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
        XCTAssertTrue(tile(app, "Honeycomb Rewards").disappears(within: 3))
        XCTAssertTrue(tile(app, "Nordic Nest Home").exists)
    }

    /// Notes written in the form are saved with the card and show on its screen,
    /// on lines of their own, and the form opens on them again (CARD-14).
    @MainActor
    func testWriteNotes() throws {
        let app = launchWithSeededCards()
        let honeycomb = tile(app, "Honeycomb Rewards")
        XCTAssertTrue(waitForElement(honeycomb))
        honeycomb.tap()
        let edit = app.buttons["editCardButton"]
        XCTAssertTrue(waitForElement(edit))
        XCTAssertFalse(app.staticTexts["cardNotesText"].exists, "A card without notes shows no notes")
        edit.tap()

        // The form's rows below the screen do not exist until it is scrolled to them.
        XCTAssertTrue(waitForElement(app.buttons["saveCardButton"]))
        let notesField = app.textFields["notesTextField"]
        XCTAssertTrue(app.reveal(notesField), "Could not scroll to the notes field")
        notesField.tap()
        notesField.typeText("Points reset each January.\nAsk for a paper receipt.")
        app.buttons["saveCardButton"].tap()

        let notes = app.staticTexts["cardNotesText"]
        XCTAssertTrue(waitForElement(notes), "The card's screen shows no notes")
        XCTAssertTrue(notes.label.contains("Points reset each January."), notes.label)
        XCTAssertTrue(notes.label.contains("\nAsk for a paper receipt."), "The notes lost their line break: \(notes.label)")

        edit.tap()
        XCTAssertTrue(waitForElement(app.buttons["saveCardButton"]))
        XCTAssertTrue(app.reveal(notesField), "Could not scroll to the notes field again")
        XCTAssertTrue(waitForValue(notesField, "Points reset each January.\nAsk for a paper receipt."))
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
        XCTAssertTrue(basket.disappears(within: 3), "Choosing an icon closes the grid")
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
        // Far below the sheet's first height: swipe the sheet open and scroll to
        // it. A press held before the drag tapped the icon under it on iOS 18.1,
        // which chose it and closed the sheet.
        let pushchair = app.buttons["cardIcon_stroller.fill"]
        let grid = app.scrollViews.containing(.any, identifier: "cardIconGrid").firstMatch
        XCTAssertTrue(waitForElement(grid), "The icon grid did not open")
        for _ in 0..<10 where !(pushchair.exists && pushchair.isHittable) {
            grid.swipeUp()
        }
        XCTAssertTrue(grid.exists, "Scrolling the grid chose an icon, which closed it")
        pushchair.tap()
        XCTAssertTrue(pushchair.disappears(within: 3), "Choosing an icon closes the grid")
        XCTAssertEqual(iconRow.value as? String, "Pushchair")

        iconRow.tap()
        XCTAssertTrue(waitForElement(pushchair))
        XCTAssertTrue(pushchair.isHittable, "The grid opens at the chosen icon")
        let basket = app.buttons["cardIcon_basket.fill"]
        XCTAssertFalse(basket.exists && basket.isHittable, "The grid is not at its top")
    }
}
