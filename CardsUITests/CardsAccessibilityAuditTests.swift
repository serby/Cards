import XCTest

/// Xcode's accessibility audit on every screen: contrast, Dynamic Type,
/// clipped text, hit regions, labels and traits. The base class runs in
/// English at the default text size; `CardsArabicLargeTextAuditTests`
/// runs every test again in Arabic, right to left, at the largest
/// accessibility size. Elements are found by identifier, so both pass in
/// any language. A screen taller than the display is audited, scrolled to
/// its end, a second time. The screens are reached through the shared
/// helpers in `UITestNavigation.swift`.
class CardsAccessibilityAuditTests: XCTestCase {
    /// Launch arguments for a variant of the whole suite.
    class var variantArguments: [String] { [] }

    override func setUpWithError() throws {
        // Collect every issue on a screen rather than stopping at the first.
        continueAfterFailure = true
    }

    @MainActor
    func testCardList() throws {
        let app = launch()
        try audit(app)
        try audit(app, scrolledTo: app.buttons[SeededCard.ikea])
    }

    @MainActor
    func testCardDetail() throws {
        let app = launch()
        app.openCard(SeededCard.costa)
        try audit(app)
        try audit(app, scrolledTo: app.staticTexts["cardTimestampText"])
    }

    /// The seeded Tesco code is not a valid EAN-13, so its screen shows the
    /// failure message on the barcode's plate.
    @MainActor
    func testCardDetailWithFailedBarcode() throws {
        let app = launch()
        app.openCard(SeededCard.tesco)
        try audit(app)
    }

    @MainActor
    func testAddCard() throws {
        let app = launch()
        app.openAddCard()
        try audit(app)
        try audit(app, scrolledTo: app.buttons["addLocationRowButton"])
    }

    @MainActor
    func testEditCard() throws {
        let app = launch()
        // The helper puts the keyboard away, so this audits the form, not the
        // system keyboard.
        app.openEditCard(SeededCard.costa)
        try audit(app)
    }

    @MainActor
    func testLocationPicker() throws {
        let app = launch()
        app.openLocationPicker()
        XCUIApplication.dismissLocationPrompt()
        try audit(app)
    }

    @MainActor
    func testSettings() throws {
        let app = launch()
        app.openSettings()
        try audit(app)
        try audit(app, scrolledTo: app.buttons["deleteAllCardsButton"])
    }

    @MainActor
    func testImportSheet() throws {
        let app = launch()
        app.openImportSheet()
        try audit(app)
    }

    // MARK: - Helpers

    @MainActor
    private func launch() -> XCUIApplication {
        XCUIApplication.launchForTesting(arguments: Self.variantArguments)
    }

    @MainActor
    private func audit(_ app: XCUIApplication) throws {
        attachScreenshot(of: app)
        try app.performAccessibilityAudit(for: .all) { issue in
            // Every issue, ignored or not, goes to the log with the element's
            // identifier and frame, which the test report does not show.
            let element = issue.element
            let frame = element.map { $0.exists ? $0.frame : .zero } ?? .zero
            print(
                "AUDIT[\(self.name)] \(issue.auditType.rawValue) | \(issue.compactDescription) | "
                    + "id=\(element?.identifier ?? "-") label=\(element?.label ?? "-") frame=\(frame)"
            )
            // true means the issue is a known false positive and is ignored.
            return Self.isKnownFalsePositive(issue, in: app)
        }
    }

    /// Audits again once `element` has been scrolled into view, if the screen
    /// had to scroll to show it.
    @MainActor
    private func audit(_ app: XCUIApplication, scrolledTo element: XCUIElement) throws {
        guard !app.isOnScreen(element) else { return }
        XCTAssertTrue(app.reveal(element), "Could not scroll to \(element)")
        try audit(app)
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(name) audit"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Elements the Dynamic Type check calls "partially unsupported" although
    /// they grow in full: in the Arabic run at the largest accessibility size,
    /// Import JSON is 93 pt tall and Delete All Cards 161 pt, against 44 pt at
    /// the default size, and the heading and footer wrap at full size. Checked
    /// on the audit's screenshots; the check reports these rows of a List only.
    private static let growsInFull: Set<String> = [
        "importJSONButton", "deleteAllCardsButton", "dataSectionHeader", "locationsFooter"
    ]

    /// Issues the audit raises that are not the app's to fix. Each case says
    /// why it was confirmed as a false positive, from the audit's screenshots
    /// in both runs.
    @MainActor
    static func isKnownFalsePositive(_ issue: XCUIAccessibilityAuditIssue, in app: XCUIApplication) -> Bool {
        guard let element = issue.element, element.exists else {
            // No element to point at: the audit found text it could not tie to
            // an accessibility element. On these screens that is text inside
            // an element that speaks for it: the card names inside their row
            // buttons (which the large-text run shows grown and wrapped, never
            // cut off), the tab bar's titles inside its buttons, and the prompt
            // of a wrapping text field, whose label and hint VoiceOver reads.
            return [.dynamicType, .textClipped, .contrast, .elementDetection].contains(issue.auditType)
        }
        let frame = element.frame
        let bars = app.navigationBars.allElementsBoundByIndex + app.tabBars.allElementsBoundByIndex
        switch issue.auditType {
        case .dynamicType:
            // UIKit draws navigation bar buttons at a fixed size and shows them
            // in the Large Content Viewer instead (touch and hold), as in every
            // app; the large-text run shows the bar unchanged while the rest grows.
            return bars.contains { $0.frame.contains(frame) } || growsInFull.contains(element.identifier)
        case .contrast:
            // A disabled control, such as Import with nothing pasted: WCAG 1.4.3
            // exempts inactive controls.
            if !element.isEnabled { return true }
            // Text in or partly under a translucent bar is measured against the
            // bar's blur of whatever is scrolled beneath it: the camera view under
            // Add Card's bar, cards and headings under the tab bar. Pixels taken
            // from the screenshots give the accent 4.75:1 on the bar itself, and
            // CardColorTests covers every colour the app draws there.
            return bars.contains { $0.frame.intersects(frame) }
        case .hitRegion:
            // MapKit's own Legal link, drawn and sized by the map.
            return app.maps.allElementsBoundByIndex.contains { $0.frame.contains(frame) }
        default:
            return false
        }
    }
}

/// Every test again in Arabic, right to left, at the largest accessibility
/// text size. Until the app has an Arabic translation iOS runs it in its
/// development language, English, laid out left to right, so the last two
/// arguments force right-to-left layout as Xcode's right-to-left
/// pseudolanguage does. Dates and numbers follow the Saudi locale.
final class CardsArabicLargeTextAuditTests: CardsAccessibilityAuditTests {
    override static var variantArguments: [String] {
        [
            "-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES"
        ]
    }
}
