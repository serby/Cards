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
    /// Ladbroke Library, whose code EAN-13 cannot draw, first in the list when
    /// the app is launched with `cardThatCannotDraw`.
    static let ladbrokeLibrary = "cardRow_50123456789012"
    /// The launch arguments that add Ladbroke Library first in the list, with
    /// the card for where you are off, so its tile is the first thing there.
    static let cardThatCannotDraw = ["-cardThatCannotDraw", "-cardSortOrder", "custom", "-showsCardWhereYouAre", "NO"]

    /// Every row, in list order.
    static let all = [joesMarket, localRoast, greenLeaf, boulderBarn, honeycomb, nordicNest]
}

/// Getting around the app, so every UI test that visits a screen reaches it
/// the same way. Elements are found by identifier, and tabs by position,
/// never by their text, so all of it works in any language and either
/// direction.
@MainActor
extension XCUIApplication {
    /// The app as every UI test launches it, not yet launched: `-uiTesting`,
    /// for an in-memory store and the shipping UI, `-disableAnimations`, so
    /// XCUITest never waits for an animation to end
    /// (`DevelopmentHooks.disableAnimationsIfRequested`), British English
    /// unless `arguments` choose a language or region, then `arguments`.
    static func forTesting(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-disableAnimations"] + britishEnglish(unlessSetIn: arguments) + arguments
        return app
    }

    /// The tests expect British English ("metres", "colour"), the app's own.
    /// A simulator takes its language and region from its Mac, British on
    /// Paul's but American on GitHub's runners, where VoiceOver said "750
    /// meters" and the Distances test failed, so the tests set it themselves.
    private static func britishEnglish(unlessSetIn arguments: [String]) -> [String] {
        arguments.contains { $0 == "-AppleLanguages" || $0 == "-AppleLocale" }
            ? []
            : ["-AppleLanguages", "(en-GB)", "-AppleLocale", "en_GB"]
    }

    /// Launches with an in-memory store, and with the six screenshot cards
    /// unless `seeded` is false, then waits for the list. The seeded cards are
    /// seen from a fixed place (`ScreenshotSeed.location`), so the app never
    /// asks for location access while they are in use, and UI tests schedule
    /// no arrival reminders (`DevelopmentHooks.notifications`), so it never
    /// asks to send notifications either.
    static func launchForTesting(seeded: Bool = true, arguments: [String] = []) -> XCUIApplication {
        let app = forTesting((seeded ? ["-screenshotSeed"] : []) + arguments)
        if seeded {
            app.launchEnvironment["CARDS_SCREENSHOT_SEED"] = "1"
        }
        app.launch()
        let add = seeded ? app.buttons["addCardButton"] : app.buttons["addFirstCardButton"]
        XCTAssertTrue(add.appears(within: 5), "The card list did not appear")
        return app
    }

    /// A card's tile by its row's identifier (`SeededCard`), so it is found in
    /// any language, however a translation orders the tile's label. The first
    /// match, as a tile that moves is briefly in the grid twice.
    func tile(_ row: String) -> XCUIElement {
        buttons.matching(identifier: row).firstMatch
    }

    /// A tap while the list is still settling just after launch can miss, as
    /// a press can (`openMenu`), so it taps again while the row is still there.
    func openCard(_ row: String) {
        let name = staticTexts["cardNameText"]
        for _ in 0..<3 {
            buttons[row].tap()
            if name.appears(within: 3) { break }
            guard buttons[row].exists, buttons[row].isHittable else { break }
        }
        XCTAssertTrue(name.appears(within: 5), "The card's screen did not open")
    }

    /// Opens the screen of Ladbroke Library, whose code EAN-13 cannot draw, so
    /// the screen shows the failure message on the barcode's plate. Launch the
    /// app with `SeededCard.cardThatCannotDraw` to have the card.
    func openCardWithFailedBarcode() {
        openCard(SeededCard.ladbrokeLibrary)
    }

    /// Whether `element` has keyboard focus within `timeout` seconds.
    static func gainsFocus(_ element: XCUIElement, within timeout: TimeInterval) -> Bool {
        element.matches(NSPredicate(format: "hasKeyboardFocus == true"), within: timeout)
    }

    /// The list's toolbar button, or the empty list's own button when there are
    /// no cards.
    func openAddCard() {
        let toolbarButton = buttons["addCardButton"]
        (toolbarButton.exists ? toolbarButton : buttons["addFirstCardButton"]).tap()
        XCTAssertTrue(buttons["saveCardButton"].appears(within: 5), "The Add Card form did not open")
    }

    /// Opens the card's form with the keyboard down. The name field takes
    /// focus after a moment, and the keyboard would cover the form.
    func openEditCard(_ row: String) {
        openCard(row)
        buttons["editCardButton"].tap()
        XCTAssertTrue(buttons["saveCardButton"].appears(within: 5), "The card's form did not open")
        dismissKeyboard()
    }

    /// Opens the Add Location map from the Add Card form. Without the seeded
    /// cards' fixed place the system asks for location access as it opens
    /// (`locationPrompt()`); with them it never does.
    func openLocationPicker() {
        openAddCard()
        let addLocation = buttons["addLocationRowButton"]
        XCTAssertTrue(reveal(addLocation), "Could not scroll to Add Location")
        addLocation.tap()
        XCTAssertTrue(buttons["addLocationButton"].appears(within: 5), "The Add Location map did not open")
    }

    /// A tab. On iPhone it is a button of the tab bar, found by position as tab
    /// titles are translated; the order of the elements stays the same right
    /// to left, only the drawing flips. From iPadOS 18 the tabs float at the
    /// top, outside any tab bar, as radio buttons that take their symbols'
    /// names as identifiers, and iPadOS 26 lists a button by that name too, so
    /// the radio button is the one to tap.
    func tab(_ position: Int, symbol: String) -> XCUIElement {
        if tabBars.firstMatch.exists { return tabBars.buttons.element(boundBy: position) }
        let radio = radioButtons.matching(identifier: symbol).firstMatch
        return radio.exists ? radio : buttons.matching(identifier: symbol).firstMatch
    }

    /// The Cards tab, the first.
    var cardsTab: XCUIElement { tab(0, symbol: "barcode") }

    /// The Settings tab, the second.
    var settingsTab: XCUIElement { tab(1, symbol: "gearshape") }

    func openSettings() {
        settingsTab.tap()
        XCTAssertTrue(switches["brightnessBoostToggle"].appears(within: 5), "Settings did not open")
    }

    func openImportSheet() {
        openSettings()
        let importButton = buttons["importJSONButton"]
        XCTAssertTrue(reveal(importButton), "Could not scroll to Import JSON")
        importButton.tap()
        XCTAssertTrue(textViews["importTextEditor"].appears(within: 5), "The import sheet did not open")
    }

    /// Long-presses `row` until its menu shows `item`. A press while the list
    /// is still settling, after launch or a move, can miss, so it lets the
    /// list settle and tries again. The first press goes at once.
    func openMenu(on row: XCUIElement, showing item: XCUIElement) -> Bool {
        for attempt in 0..<3 {
            if attempt > 0 {
                RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            }
            row.press(forDuration: 1.2)
            if item.appears(within: 3) { return true }
        }
        return false
    }

    /// Swipes up until `element` is fully on screen, clear of the tab bar.
    @discardableResult
    func reveal(_ element: XCUIElement) -> Bool {
        // Settings in French at the largest text size took more than 8 to reach Import JSON.
        for _ in 0..<16 {
            if isOnScreen(element) { return true }
            swipeUp(velocity: .slow)
        }
        return isOnScreen(element)
    }

    /// Swipes up until the screen stops moving, so whatever comes after the
    /// last control, such as a section's footer, is clear of the tab bar too.
    func scrollToEnd() {
        for _ in 0..<16 {
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
        guard keyboard.appears(within: 2) else { return }
        for _ in 0..<3 where keyboard.exists {
            typeText("\n")
        }
        XCTAssertTrue(keyboard.disappears(within: 1), "The keyboard stayed up")
    }

    /// A prompt SpringBoard shows over the app, such as for location access or
    /// notifications, if one is up within `timeout` seconds.
    static func systemPrompt(timeout: TimeInterval = 3) -> XCUIElement? {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        return alert.appears(within: timeout) ? alert : nil
    }

    /// The location access prompt, which the Add Location map raises the first
    /// time it opens without the seeded cards' fixed place.
    static func locationPrompt(timeout: TimeInterval = 3) -> XCUIElement? {
        systemPrompt(timeout: timeout)
    }
}
