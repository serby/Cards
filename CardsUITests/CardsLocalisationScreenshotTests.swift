import XCTest

/// Screenshots of every screen, for checking a translation by eye: cut-off
/// or overlapping text, untranslated copy, mirroring and number formats.
/// It visits what the accessibility audit visits, through the same helpers,
/// plus the empty list, a card's menu, the location prompt, a place in the
/// form and the delete-all confirmation.
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
        capture("01-list")
        captureScrolled(app, to: app.buttons[SeededCard.ikea], "02-list-end")
    }

    /// Costa is in the middle, so its menu offers Move Up and Move Down.
    @MainActor
    func testCardMenu() {
        let app = launch()
        let costa = app.buttons[SeededCard.costa]
        XCTAssertTrue(app.openMenu(on: costa, showing: app.buttons["deleteCardMenuItem"]), "The card's menu did not open")
        capture("03-card-menu")
    }

    @MainActor
    func testEmptyList() {
        _ = launch(seeded: false)
        capture("04-empty")
    }

    @MainActor
    func testCardDetail() {
        let app = launch()
        app.openCard(SeededCard.costa)
        capture("05-detail")
        captureScrolled(app, to: app.staticTexts["cardTimestampText"], "06-detail-end")
    }

    /// The seeded Tesco code is not a valid EAN-13, so its screen shows the
    /// failure message on the barcode's plate.
    @MainActor
    func testCardDetailWithFailedBarcode() {
        let app = launch()
        app.openCard(SeededCard.tesco)
        capture("07-detail-failed-barcode")
    }

    @MainActor
    func testAddCard() {
        let app = launch()
        app.openAddCard()
        capture("08-add")
        captureScrolled(app, to: app.buttons["addLocationRowButton"], "09-add-end")
    }

    @MainActor
    func testEditCard() {
        let app = launch()
        app.openEditCard(SeededCard.costa)
        capture("10-edit")
    }

    /// The prompt shows the app's own reason for asking, from InfoPlist, but
    /// only the first time, so the script installs the app afresh for each run.
    /// A place added with the pin and no name shows in the form with its radius.
    @MainActor
    func testLocationPicker() {
        let app = launch()
        app.openLocationPicker()
        if let prompt = XCUIApplication.locationPrompt() {
            capture("11-location-prompt")
            prompt.buttons.element(boundBy: prompt.buttons.count - 1).tap()
        }
        capture("12-location-picker")

        let add = app.buttons["addLocationButton"]
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: add)
        wait(for: [enabled], timeout: 10)
        add.tap()
        let addLocation = app.buttons["addLocationRowButton"]
        XCTAssertTrue(addLocation.waitForExistence(timeout: 5), "The form did not come back")
        XCTAssertTrue(app.reveal(addLocation), "Could not scroll to the new place")
        capture("13-add-with-location")
    }

    @MainActor
    func testSettings() {
        let app = launch()
        app.openSettings()
        capture("14-settings")
        captureScrolled(app, to: app.buttons["deleteAllCardsButton"], "15-settings-end")
    }

    @MainActor
    func testDeleteAllConfirmation() {
        let app = launch()
        app.openSettings()
        let deleteAll = app.buttons["deleteAllCardsButton"]
        XCTAssertTrue(app.reveal(deleteAll), "Could not scroll to Delete All Cards")
        deleteAll.tap()
        XCTAssertTrue(app.buttons["confirmDeleteAllButton"].waitForExistence(timeout: 5), "The confirmation did not appear")
        capture("16-delete-confirmation")
    }

    @MainActor
    func testImportSheet() {
        let app = launch()
        app.openImportSheet()
        capture("17-import")
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

    /// The screen again scrolled to `element`, if it had to scroll to show it.
    @MainActor
    private func captureScrolled(_ app: XCUIApplication, to element: XCUIElement, _ name: String) {
        guard !app.isOnScreen(element) else { return }
        XCTAssertTrue(app.reveal(element), "Could not scroll to \(element)")
        capture(name)
    }
}
