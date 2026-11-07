//
//  CardsUITests.swift
//  CardsUITests
//
//  Created by Serby, Paul on 18/12/2024.
//

import XCTest

/// What the UI test classes share: the variant they run in, and helpers for
/// reading the grid and waiting on labels. No tests of its own. The tests are
/// split between `CardsUITests` and `CardPlacesAndSettingsUITests`, each with
/// a right-to-left twin, so a parallel run spreads them over four simulators.
class CardsUITestCase: XCTestCase {
    /// Launch arguments for a variant of the suite, such as another language.
    class var variantArguments: [String] { [] }
    /// Whether the variant lays the app out right to left.
    class var isRightToLeft: Bool { false }

    /// Whether the tile `first` comes before `second` in the grid: on an earlier
    /// row, or on the same row nearer its leading edge, the right right to left.
    @MainActor
    func readsBefore(_ first: XCUIElement, _ second: XCUIElement) -> Bool {
        let one = first.frame
        let other = second.frame
        guard abs(one.minY - other.minY) < 1 else { return one.minY < other.minY }
        return Self.isRightToLeft ? one.maxX > other.maxX : one.minX < other.minX
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    /// Waits for a label to change. A predicate re-reads the element; `wait(for:toEqual:)` missed the change.
    @MainActor
    func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval) -> Bool {
        element.matches(NSPredicate(format: "label == %@", label), within: timeout)
    }

    /// The launch arguments for right to left. No right-to-left language ships
    /// yet (Arabic is held back, l10n/context.md), so the run forces the
    /// direction in English, as a right-to-left language would set it;
    /// `CardsRightToLeftUITests.testLaysOutRightToLeft` fails if the forcing
    /// stops working.
    static let rightToLeft = ["-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES"]
}

/// Adds, finds, reorders and deletes cards on the Cards tab. The branch's
/// tests find elements by identifier, never by their English text; some of
/// 1.4's still read English labels, so the suite runs in English.
/// `CardsRightToLeftUITests` runs it again right to left.
class CardsUITests: CardsUITestCase {
    @MainActor
    func testAdd() throws {
        let app = XCUIApplication.forTesting(Self.variantArguments)
        app.launch()

        // The store starts empty, so the list shows its own Add Card button.
        let addButton = app.buttons["addFirstCardButton"]
        XCTAssertTrue(addButton.appears(within: 5), "addFirstCardButton did not appear")
        addButton.tap()

        let nameField = app.textFields["nameTextField"]
        XCTAssertTrue(nameField.appears(within: 5), "nameTextField did not appear")
        let codeField = app.textFields["codeTextField"]

        let testName = "Test Name"
        let testCode = "Test Code"
        nameField.tap()
        nameField.typeText(testName)
        codeField.tap()
        codeField.typeText(testCode)

        app.buttons["saveCardButton"].tap()

        let name = app.staticTexts["cardNameText"]
        XCTAssertTrue(name.appears(within: 5), "The card's screen did not open")
        XCTAssertTrue(name.label.contains(testName), "Name shows '\(name.label)'")
        let code = app.staticTexts["cardCodeText"]
        XCTAssertTrue(code.label.contains(testCode), "Code shows '\(code.label)'")
    }

    /// Reordering and deleting do not need a drag or a swipe: each card's
    /// menu does both, for pointer, keyboard, Voice Control and Switch
    /// Control users.
    @MainActor
    func testMoveAndDeleteFromTheMenu() throws {
        let app = XCUIApplication.launchForTesting(arguments: Self.variantArguments)

        // The first two seeded cards.
        let joesMarket = app.buttons[SeededCard.joesMarket]
        let localRoast = app.buttons[SeededCard.localRoast]
        XCTAssertTrue(joesMarket.appears(within: 5))
        // Side by side on the grid's first row.
        XCTAssertTrue(readsBefore(joesMarket, localRoast), "Joe's Market is not first")

        let moveDown = app.buttons["moveCardDownMenuItem"]
        XCTAssertTrue(app.openMenu(on: joesMarket, showing: moveDown), "The card's menu did not open")
        XCTAssertFalse(app.buttons["moveCardUpMenuItem"].exists, "The first card offered to move up")
        moveDown.tap()
        XCTAssertTrue(eventually { readsBefore(localRoast, joesMarket) }, "Joe's Market did not move after Local Roast Coffee")

        let delete = app.buttons["deleteCardMenuItem"]
        XCTAssertTrue(app.openMenu(on: joesMarket, showing: delete), "The card's menu did not open")
        delete.tap()
        XCTAssertTrue(eventually { !joesMarket.exists }, "Joe's Market was not deleted")
        XCTAssertTrue(localRoast.exists)
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

    /// Typing in the search field narrows the grid to the names that match (CARD-11).
    @MainActor
    func testSearchFiltersCards() throws {
        let app = launchWithSeededCards()
        let search = app.searchFields.firstMatch
        // iOS 27 keeps the field out of sight until the grid is pulled down, so
        // pull it down as a person would.
        if !search.appears(within: 3) {
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(waitForElement(search))
        search.tap()
        search.typeText("hon")
        XCTAssertTrue(waitForElement(tile(app, "Honeycomb Rewards")))
        XCTAssertTrue(tile(app, "Joe's Market").disappears(within: 3))

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
        XCTAssertTrue(honeycomb.disappears(within: 3))
        XCTAssertTrue(tile(app, "Nordic Nest Home").exists)
    }

    /// In custom order, a tile dropped on another takes its place (CARD-7, CARD-10).
    @MainActor
    func testDragATileToReorder() throws {
        let app = launchWithSeededCards()
        let honeycomb = tile(app, "Honeycomb Rewards")
        let joesMarket = tile(app, "Joe's Market")
        XCTAssertTrue(waitForElement(honeycomb))
        // Moved as soon as the tile lifts, before its menu opens: the menu now
        // offers Move Up and Move Down too, opens in the drag's path, and after
        // a one-second press the drag ran onto it and never left the tile.
        // Held over the target so it takes the drop.
        honeycomb.press(forDuration: 0.6, thenDragTo: joesMarket, withVelocity: .slow, thenHoldForDuration: 1)

        // Honeycomb Rewards is now first, and Joe's Market moved along beside it.
        XCTAssertTrue(
            eventually { readsBefore(honeycomb, joesMarket) && abs(honeycomb.frame.minY - joesMarket.frame.minY) < 1 },
            "Honeycomb Rewards did not take Joe's Market's place"
        )
    }

    /// Location order puts the cards with places first and Honeycomb Rewards, which has
    /// none, last; custom order puts it back (CARD-11). The choice is kept, so
    /// the test ends on custom order.
    @MainActor
    func testSortMenuChangesTheOrder() throws {
        // Not pinned, as launchWithSeededCards does, so the menu can change it.
        let app = XCUIApplication.forTesting(["-screenshotSeed", "-showsCardWhereYouAre", "NO"])
        app.launch()
        let honeycomb = tile(app, "Honeycomb Rewards")
        let nordicNest = tile(app, "Nordic Nest Home")
        XCTAssertTrue(waitForElement(honeycomb))

        choose(app, sortOrder: "Location")
        XCTAssertTrue(
            eventually { honeycomb.frame.minY > nordicNest.frame.minY || honeycomb.frame.minX > nordicNest.frame.minX },
            "Honeycomb Rewards did not move last"
        )

        choose(app, sortOrder: "Custom Order")
        XCTAssertTrue(
            eventually { abs(honeycomb.frame.minY - nordicNest.frame.minY) < 1 && honeycomb.frame.minX < nordicNest.frame.minX },
            "Honeycomb Rewards did not move back beside Nordic Nest Home"
        )
    }

    /// With Show Card Where I Am on, the card for where you are is shown in
    /// full above the grid, and opens when tapped (SET-3).
    @MainActor
    func testCardWhereYouAre() throws {
        let app = XCUIApplication.forTesting(["-screenshotSeed", "-cardSortOrder", "custom", "-showsCardWhereYouAre", "YES"])
        app.launch()

        // The seed puts the user inside Joe's Market Notting Hill.
        let cardHere = app.buttons["cardWhereYouAre"]
        XCTAssertTrue(waitForElement(cardHere))
        XCTAssertEqual(cardHere.label, "Joe's Market, You're at Joe's Market Notting Hill")
        XCTAssertTrue(tile(app, "Local Roast Coffee").exists)
        cardHere.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["cardNameText"], "Joe's Market", timeout: 5))
    }

    @MainActor
    private func choose(_ app: XCUIApplication, sortOrder: String) {
        app.buttons["sortMenu"].tap()
        let option = app.buttons[sortOrder]
        XCTAssertTrue(waitForElement(option))
        option.tap()
    }
}

/// Every test again right to left (`CardsUITestCase.rightToLeft`), as the
/// tests must not depend on the direction.
final class CardsRightToLeftUITests: CardsUITests {
    override static var variantArguments: [String] { rightToLeft }
    override static var isRightToLeft: Bool { true }

    /// The first tab, Cards, is drawn on the right.
    @MainActor
    func testLaysOutRightToLeft() {
        let app = XCUIApplication.launchForTesting(seeded: false, arguments: Self.variantArguments)
        let tabs = app.tabBars.buttons
        XCTAssertGreaterThan(
            tabs.element(boundBy: 0).frame.minX,
            tabs.element(boundBy: 1).frame.minX,
            "The right-to-left run is laid out left to right"
        )
    }
}
