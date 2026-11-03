import XCTest

/// Screenshots of every screen, for checking a translation by eye: cut-off
/// or overlapping text, untranslated copy, mirroring and number formats.
/// It visits what the accessibility audit visits, through the same helpers,
/// plus the empty list, a card's menu, the location prompt, a place in the
/// form and the delete-all confirmation. A screen that scrolls is captured
/// a page at a time to its end ("06-add", "06-add-2", …), so nothing between
/// its top and its end goes unseen.
///
/// `scripts/capture-l10n.ts` (`make capture-l10n`) runs it once per language
/// and text size, with `-testLanguage` and `-testRegion`, and saves each
/// attachment as `<language>/<size>/<name>.png`. Anywhere else it is skipped,
/// so `make test` and CI spend no time on it: the script sets
/// `CARDS_L10N_CAPTURE` and the text size in the runner's environment through
/// xcodebuild's `TEST_RUNNER_` prefix.
final class CardsLocalisationScreenshotTests: XCTestCase {
    private static let environment = ProcessInfo.processInfo.environment

    /// The text size, as a content size category such as
    /// `UICTContentSizeCategoryAccessibilityXXXL`, or the simulator's own.
    private static var launchArguments: [String] {
        guard let size = environment["CARDS_L10N_CONTENT_SIZE"], !size.isEmpty else { return [] }
        return ["-UIPreferredContentSizeCategoryName", size]
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(
            Self.environment["CARDS_L10N_CAPTURE"] == "1",
            "Localisation screenshots run from scripts/capture-l10n.ts only"
        )
        // A screen that cannot be reached is a failure, but the screens after
        // it in the same test are still worth having.
        continueAfterFailure = true
    }

    @MainActor
    func testCardList() {
        let app = launch()
        capturePages(app, "01-list")
    }

    /// Costa is in the middle, so its menu offers Move Up and Move Down.
    @MainActor
    func testCardMenu() {
        let app = launch()
        let costa = app.buttons[SeededCard.costa]
        XCTAssertTrue(app.openMenu(on: costa, showing: app.buttons["deleteCardMenuItem"]), "The card's menu did not open")
        capture("02-card-menu")
    }

    @MainActor
    func testEmptyList() {
        _ = launch(seeded: false)
        capture("03-empty")
    }

    @MainActor
    func testCardDetail() {
        let app = launch()
        app.openCard(SeededCard.costa)
        capturePages(app, "04-detail")
    }

    /// The seeded Tesco code is not a valid EAN-13, so its screen shows the
    /// failure message on the barcode's plate.
    @MainActor
    func testCardDetailWithFailedBarcode() {
        let app = launch()
        app.openCard(SeededCard.tesco)
        capturePages(app, "05-detail-failed-barcode")
    }

    @MainActor
    func testAddCard() {
        let app = launch()
        app.openAddCard()
        capturePages(app, "06-add")
    }

    @MainActor
    func testEditCard() {
        let app = launch()
        app.openEditCard(SeededCard.costa)
        capturePages(app, "07-edit")
    }

    /// The prompt shows the app's own reason for asking, from InfoPlist, but
    /// only the first time, so the script installs the app afresh for each run.
    /// A place added with the pin and no name shows in the form with its radius.
    @MainActor
    func testLocationPicker() {
        let app = launch()
        app.openLocationPicker()
        if let prompt = XCUIApplication.locationPrompt() {
            capture("08-location-prompt")
            prompt.buttons.element(boundBy: prompt.buttons.count - 1).tap()
        }
        capture("09-location-picker")

        let add = app.buttons["addLocationButton"]
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: add)
        wait(for: [enabled], timeout: 10)
        add.tap()
        let addLocation = app.buttons["addLocationRowButton"]
        XCTAssertTrue(addLocation.waitForExistence(timeout: 5), "The form did not come back")
        XCTAssertTrue(app.reveal(addLocation), "Could not scroll to the new place")
        capture("10-add-with-location")
    }

    @MainActor
    func testSettings() {
        let app = launch()
        app.openSettings()
        capturePages(app, "11-settings")
    }

    @MainActor
    func testDeleteAllConfirmation() {
        let app = launch()
        app.openSettings()
        let deleteAll = app.buttons["deleteAllCardsButton"]
        XCTAssertTrue(app.reveal(deleteAll), "Could not scroll to Delete All Cards")
        deleteAll.tap()
        XCTAssertTrue(app.buttons["confirmDeleteAllButton"].waitForExistence(timeout: 5), "The confirmation did not appear")
        capture("12-delete-confirmation")
    }

    @MainActor
    func testImportSheet() {
        let app = launch()
        app.openImportSheet()
        capture("13-import")
    }

    // MARK: - Helpers

    @MainActor
    private func launch(seeded: Bool = true) -> XCUIApplication {
        XCUIApplication.launchForTesting(seeded: seeded, arguments: Self.launchArguments)
    }

    /// The whole screen, so a system prompt over the app is in the picture.
    @MainActor
    private func capture(_ name: String) {
        // Let a push, a sheet or a scroll stop moving first.
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The screen, then a page further down at a time until it stops moving:
    /// `name`, `name-2`, `name-3`. Each drag moves half the screen, less than
    /// the part between the bars, so the pages overlap and nothing between
    /// them is missed.
    @MainActor
    private func capturePages(_ app: XCUIApplication, _ name: String) {
        capture(name)
        for page in 2...10 {
            let before = app.layoutSignature
            // At the screen's edge, in the margin beside the rows, so the drag
            // never starts on a control: on the barcode type menu it opened the
            // menu instead of scrolling.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.75))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.25))
            // Slowly and held, so the content moves with the finger and does not fling.
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            guard app.layoutSignature != before else { return }
            capture("\(name)-\(page)")
        }
    }
}
