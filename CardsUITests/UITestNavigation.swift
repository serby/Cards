import XCTest

/// The seeded cards (user content, so never translated) by their rows'
/// identifiers.
enum SeededCard {
    /// The first card. Its code is not a valid EAN-13, so its screen shows
    /// the failure message on the barcode's plate.
    static let tesco = "cardRow_634004024987531"
    static let costa = "cardRow_1234567890128"
    /// The last card, below the fold at large text sizes.
    static let ikea = "cardRow_7350053850019"
}

/// Getting around the app, so every UI test that visits a screen reaches it
/// the same way. Elements are found by identifier, and tabs by position,
/// never by their text, so all of it works in any language and either
/// direction.
@MainActor
extension XCUIApplication {
    /// Launches with an in-memory store, and with the six screenshot cards
    /// unless `seeded` is false, then waits for the list.
    static func launchForTesting(seeded: Bool = true, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"] + (seeded ? ["-screenshotSeed"] : []) + arguments
        if seeded {
            app.launchEnvironment["CARDS_SCREENSHOT_SEED"] = "1"
        }
        app.launch()
        let add = seeded ? app.buttons["addCardButton"] : app.buttons["addFirstCardButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "The card list did not appear")
        return app
    }

    func openCard(_ row: String) {
        buttons[row].tap()
        XCTAssertTrue(staticTexts["cardNameText"].waitForExistence(timeout: 5), "The card's screen did not open")
    }

    func openAddCard() {
        buttons["addCardButton"].tap()
        XCTAssertTrue(buttons["saveCardButton"].waitForExistence(timeout: 5), "The Add Card form did not open")
    }

    /// Opens the card's form with the keyboard down. The name field takes
    /// focus after a moment, and the keyboard would cover the form.
    func openEditCard(_ row: String) {
        openCard(row)
        buttons["editCardButton"].tap()
        XCTAssertTrue(buttons["saveCardButton"].waitForExistence(timeout: 5), "The card's form did not open")
        dismissKeyboard()
    }

    /// Opens the Add Location map from the Add Card form. The system may ask
    /// for location access as it opens; see `dismissLocationPrompt()`.
    func openLocationPicker() {
        openAddCard()
        let addLocation = buttons["addLocationRowButton"]
        XCTAssertTrue(reveal(addLocation), "Could not scroll to Add Location")
        addLocation.tap()
        XCTAssertTrue(buttons["addLocationButton"].waitForExistence(timeout: 5), "The Add Location map did not open")
    }

    func openSettings() {
        // By position, as tab titles are translated. The order of the elements
        // stays the same right to left; only the drawing flips.
        tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(switches["brightnessBoostToggle"].waitForExistence(timeout: 5), "Settings did not open")
    }

    func openImportSheet() {
        openSettings()
        let importButton = buttons["importJSONButton"]
        XCTAssertTrue(reveal(importButton), "Could not scroll to Import JSON")
        importButton.tap()
        XCTAssertTrue(textViews["importTextEditor"].waitForExistence(timeout: 5), "The import sheet did not open")
    }

    /// Long-presses `row` until its menu shows `item`. A press while the list
    /// is still settling, after launch or a move, can miss, so it tries again.
    func openMenu(on row: XCUIElement, showing item: XCUIElement) -> Bool {
        for _ in 0..<3 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            row.press(forDuration: 1.2)
            if item.waitForExistence(timeout: 3) { return true }
        }
        return false
    }

    /// Swipes up until `element` is fully on screen, clear of the tab bar.
    @discardableResult
    func reveal(_ element: XCUIElement) -> Bool {
        for _ in 0..<8 {
            if isOnScreen(element) { return true }
            swipeUp(velocity: .slow)
        }
        return isOnScreen(element)
    }

    func isOnScreen(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let tabBar = tabBars.firstMatch
        let bottom = tabBar.exists ? tabBar.frame.minY : frame.maxY
        return element.frame.maxY <= bottom
    }

    /// Return moves from the name to the code field and then ends editing.
    func dismissKeyboard() {
        let keyboard = keyboards.firstMatch
        guard keyboard.waitForExistence(timeout: 2) else { return }
        for _ in 0..<3 where keyboard.exists {
            typeText("\n")
        }
        XCTAssertFalse(keyboard.waitForExistence(timeout: 1), "The keyboard stayed up")
    }

    /// The location access prompt SpringBoard shows over the app, if it is up
    /// within `timeout` seconds.
    static func locationPrompt(timeout: TimeInterval = 3) -> XCUIElement? {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        return alert.waitForExistence(timeout: timeout) ? alert : nil
    }

    /// The Add Location map asks for location access when it first opens. Any
    /// answer will do; the prompt is the system's, not the app's.
    static func dismissLocationPrompt() {
        guard let alert = locationPrompt() else { return }
        alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
    }
}
