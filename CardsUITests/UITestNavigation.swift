import XCTest

/// The seeded cards (user content, so never translated) by their rows'
/// identifiers, which end in the card's code (`ScreenshotSeed`).
enum SeededCard {
    /// The first card, Joe's Market, with two places, the nearer one where you are.
    static let joesMarket = "cardRow_482019375610284"
    /// The second card, Local Roast Coffee.
    static let localRoast = "cardRow_1234567890128"
    static let greenLeaf = "cardRow_9780201379624"
    /// Boulder Barn Climbing, a QR code.
    static let boulderBarn = "cardRow_https://serby.net"
    static let honeycomb = "cardRow_9988776655443"
    /// The last card, Nordic Nest Home, below the fold at large text sizes.
    static let nordicNest = "cardRow_2093847561024"

    /// Every row, in list order.
    static let all = [joesMarket, localRoast, greenLeaf, boulderBarn, honeycomb, nordicNest]
}

/// Getting around the app, so every UI test that visits a screen reaches it
/// the same way. Elements are found by identifier, and tabs by position,
/// never by their text, so all of it works in any language and either
/// direction.
@MainActor
extension XCUIApplication {
    /// Launches with an in-memory store, and with the six screenshot cards
    /// unless `seeded` is false, then waits for the list. The seeded cards are
    /// seen from a fixed place (`ScreenshotSeed.location`), so the app never
    /// asks for location access while they are in use, and UI tests schedule
    /// no arrival reminders (`DevelopmentHooks.notifications`), so it never
    /// asks to send notifications either.
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

    /// A tap while the list is still settling just after launch can miss, as
    /// a press can (`openMenu`), so it taps again while the row is still there.
    func openCard(_ row: String) {
        let name = staticTexts["cardNameText"]
        for _ in 0..<3 {
            buttons[row].tap()
            if name.waitForExistence(timeout: 3) { break }
            guard buttons[row].exists, buttons[row].isHittable else { break }
        }
        XCTAssertTrue(name.waitForExistence(timeout: 5), "The card's screen did not open")
    }

    /// Opens Local Roast Coffee's screen with a code its format, EAN-13, cannot draw, so
    /// the screen shows the failure message on the barcode's plate. Every
    /// seeded code draws, so it adds a digit to Local Roast Coffee's: fourteen digits are
    /// too many for EAN-13. The form gives the name focus a moment after it
    /// opens, which would take it back from a tapped code field, so the test
    /// waits for that and then lets Return move on to the code.
    func openCardWithFailedBarcode() {
        openCard(SeededCard.localRoast)
        buttons["editCardButton"].tap()
        let name = textFields["nameTextField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "The card's form did not open")
        if !Self.gainsFocus(name, within: 3) {
            name.tap()
        }
        name.typeText("\n")
        XCTAssertTrue(Self.gainsFocus(textFields["codeTextField"], within: 2), "Return did not move on to the code")
        typeText("0")
        buttons["saveCardButton"].tap()
        XCTAssertTrue(staticTexts["cardNameText"].waitForExistence(timeout: 5), "The card's screen did not open")
    }

    /// Whether `element` has keyboard focus within `timeout` seconds.
    static func gainsFocus(_ element: XCUIElement, within timeout: TimeInterval) -> Bool {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: element)
        return XCTWaiter.wait(for: [focused], timeout: timeout) == .completed
    }

    /// The list's toolbar button, or the empty list's own button when there are
    /// no cards.
    func openAddCard() {
        let toolbarButton = buttons["addCardButton"]
        (toolbarButton.exists ? toolbarButton : buttons["addFirstCardButton"]).tap()
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

    /// The Settings tab. On iPhone it is the second button of the tab bar,
    /// found by position as tab titles are translated; the order of the
    /// elements stays the same right to left, only the drawing flips. From
    /// iPadOS 18 the tab bar floats at the top, outside any tab bar, and its
    /// buttons take their symbols' names as identifiers.
    var settingsTab: XCUIElement {
        tabBars.firstMatch.exists ? tabBars.buttons.element(boundBy: 1) : buttons["gearshape"]
    }

    func openSettings() {
        settingsTab.tap()
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

    /// Swipes up until the screen stops moving, so whatever comes after the
    /// last control, such as a section's footer, is clear of the tab bar too.
    func scrollToEnd() {
        for _ in 0..<8 {
            let before = layoutSignature
            swipeUp(velocity: .slow)
            if layoutSignature == before { return }
        }
    }

    /// Every element on screen with its frame: equal when nothing has moved.
    /// Without the snapshot's memory addresses, which differ each time, and
    /// without "Other" elements: a drag shows the scroll bars, which are those,
    /// even when the content cannot move, and their labels are translated.
    var layoutSignature: String {
        debugDescription
            .split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("Other,") }
            .joined(separator: "\n")
            .replacingOccurrences(of: "0x[0-9a-fA-F]+", with: "", options: .regularExpression)
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

    /// A prompt SpringBoard shows over the app, such as for location access or
    /// notifications, if one is up within `timeout` seconds.
    static func systemPrompt(timeout: TimeInterval = 3) -> XCUIElement? {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        return alert.waitForExistence(timeout: timeout) ? alert : nil
    }

    /// The location access prompt, which the Add Location map raises the first
    /// time it opens without the seeded cards' fixed place.
    static func locationPrompt(timeout: TimeInterval = 3) -> XCUIElement? {
        systemPrompt(timeout: timeout)
    }

    /// The Add Location map asks for location access when it first opens. Any
    /// answer will do; the prompt is the system's, not the app's.
    static func dismissLocationPrompt() {
        guard let alert = locationPrompt() else { return }
        alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
    }
}
