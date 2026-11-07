import XCTest

/// Xcode's accessibility audit on every screen: contrast, Dynamic Type,
/// clipped text, hit regions, labels and traits, in English at the default
/// text size, and again right to left at the largest accessibility size.
/// Elements are found by identifier, so both pass in any language. A screen
/// taller than the display is audited, scrolled to its end, a second time.
/// The screens are reached through the shared helpers in
/// `UITestNavigation.swift`. They are split between two classes, each with
/// its right-to-left twin, so a parallel run spreads the audits over four
/// simulators: `CardsAccessibilityAuditTests` for the list, a card's screen,
/// Settings and the import sheet, and `CardFormAccessibilityAuditTests` for
/// the forms and the map. This class holds what they share, and no tests.
class AccessibilityAuditCase: XCTestCase {
    /// Launch arguments for a variant of the whole suite.
    class var variantArguments: [String] { [] }

    /// Right to left at the largest accessibility text size. No right-to-left
    /// language ships yet (Arabic is held back, l10n/context.md), so the
    /// direction is forced in English, as a right-to-left language sets it
    /// (`CardsRightToLeftUITests.testLaysOutRightToLeft` checks it does).
    static let rightToLeftAtTheLargestSize = [
        "-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES",
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
    ]

    override func setUpWithError() throws {
        // Collect every issue on a screen rather than stopping at the first.
        continueAfterFailure = true
    }

    // MARK: - Helpers

    @MainActor
    func launch() -> XCUIApplication {
        XCUIApplication.launchForTesting(arguments: Self.variantArguments)
    }

    /// The checks that change the text size as they run: Dynamic Type, and
    /// clipped text, which tries the larger sizes.
    static let textSizeChecks: XCUIAccessibilityAuditType = [.dynamicType, .textClipped]

    /// Every check, with the ones that change the text size last and on their
    /// own. As the text shrinks and grows a screen scrolled to its end moves
    /// back to its top, so a check in the same audit judged what had been on
    /// screen by where things had moved to: in parallel runs the
    /// right-to-left audit of a card's screen at its end failed contrast on
    /// the distance, measured under the bar, where `isInScrollEdgeEffect`
    /// excuses it, but reported at the top of the screen, where it is not.
    @MainActor
    func audit(_ app: XCUIApplication) throws {
        attachScreenshot(of: app)
        try app.performAccessibilityAudit(for: XCUIAccessibilityAuditType.all.subtracting(Self.textSizeChecks)) { issue in
            self.report(issue, in: app)
        }
        try app.performAccessibilityAudit(for: Self.textSizeChecks) { issue in
            self.report(issue, in: app)
        }
    }

    /// Logs `issue`, ignored or not, with the element's identifier and frame,
    /// which the test report does not show, and says whether it is a known
    /// false positive, which the audit then ignores.
    @MainActor
    private func report(_ issue: XCUIAccessibilityAuditIssue, in app: XCUIApplication) -> Bool {
        let element = issue.element
        let frame = element.map { $0.exists ? $0.frame : .zero } ?? .zero
        let ignored = Self.isKnownFalsePositive(issue, in: app)
        print(
            "AUDIT[\(name)] \(ignored ? "ignored" : "FAILED") \(issue.auditType.rawValue) | \(issue.compactDescription) | "
                + "id=\(element?.identifier ?? "-") label=\(element?.label ?? "-") frame=\(frame)"
                + " bars=\((app.navigationBars.allElementsBoundByIndex + app.tabBars.allElementsBoundByIndex).map(\.frame))"
        )
        return ignored
    }

    /// Audits again at the screen's end, `element` included, if the screen
    /// scrolls at all. Stopping as soon as `element` showed, or not scrolling
    /// because it already showed, left whatever follows it under the tab bar
    /// unaudited: the Locations footer below Add Location.
    @MainActor
    func audit(_ app: XCUIApplication, scrolledTo element: XCUIElement) throws {
        let start = app.layoutSignature
        if !app.isOnScreen(element) {
            XCTAssertTrue(app.reveal(element), "Could not scroll to \(element)")
        }
        app.scrollToEnd()
        guard app.layoutSignature != start else { return }
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
    /// Since 1.4 made Settings and the form longer it also reports, in English
    /// at the default size, Version, its number and Created by at the foot of
    /// Settings, and Notify When I Arrive below a card's places; the
    /// right-to-left audit at the largest size shows all four grown and
    /// wrapped. On the add form only, below the camera and the photo and file
    /// rows, it reports the Code label, its prompt and the Colour heading:
    /// the same views pass on the edit form, where they sit higher, and the
    /// edit form's largest-size screenshot shows Code grown and wrapped. The
    /// check names the text in a row by its label, with no identifier, so text
    /// inside one of these counts too (`isInside`).
    private static let growsInFull: Set<String> = [
        "importJSONButton", "deleteAllCardsButton", "dataSectionHeader", "locationsFooter",
        "versionRow", "authorLink", "notifyOnArrivalToggle", "codeLabel", "wrappingPrompt", "colourSectionHeader",
        // The Distances menu's title and the units chosen, reported "partially
        // unsupported" at the default size; the largest-size run does not
        // report them, and its screenshot and `make capture-l10n` at AX5 on
        // iOS 26.5 show both grown, the units wrapped under the title.
        "distanceUnitsPicker",
        // Since the tests run on iOS 26 and 27, at the default size: the
        // footer under the Distances menu ("partially unsupported"), the edit
        // form's last row, Delete Card, and, on iOS 26 only, the add form's
        // Locations heading ("unsupported"). At the largest size the footer
        // wraps on six lines and Locations is grown and whole (`make
        // capture-l10n` on iOS 26.5), and the right-to-left audit's screenshot
        // shows Delete Card grown and whole.
        "distanceUnitsFooter", "deleteCardButton", "locationsSectionHeader"
    ]

    /// Text the clipping check says may be cut off at larger sizes, since the
    /// tests run on iOS 26 and 27, which the largest-size screenshots show
    /// grown and whole (`growsInFull`): Delete Card and Created by, the last
    /// rows of a screen scrolled to its end, and the add form's Locations
    /// heading, on iOS 26 only.
    private static let wholeAtTheLargestSize: Set<String> = ["deleteCardButton", "authorLink", "locationsSectionHeader"]

    /// A place's row in the card form. The check reports its name and radius
    /// by their text, with no identifier, as the row speaks for both
    /// (`children: .ignore`): "partially unsupported" in English at the
    /// default size, and "unsupported", with the radius "clipped", in Arabic
    /// at the largest size. The Arabic audit's screenshot shows both grown to
    /// that size and wrapped, the radius whole on its two lines, the same as
    /// the rows in `growsInFull`.
    private static let locationRow = "locationRow"

    /// Whether `frame` lies inside an element with one of `identifiers`.
    @MainActor
    private static func isInside(_ frame: CGRect, anyOf identifiers: Set<String>, in app: XCUIApplication) -> Bool {
        identifiers.contains { identifier in
            app.descendants(matching: .any).matching(identifier: identifier).allElementsBoundByIndex.contains { row in
                row.frame.insetBy(dx: -1, dy: -1).contains(frame)
            }
        }
    }

    /// Section headings, which the contrast check measures below AA when they
    /// are short words at the default text size: German ANZEIGE, FARBE and
    /// ORTE, Arabic العرض and اللون, but never English DISPLAY, COLOUR or
    /// LOCATIONS, nor any of them at the largest size. All are
    /// `Color.secondaryText`, 6.0:1 on the white of Settings and 5.4:1 on the
    /// form's grouped background (`CardColorTests`), and the darkest pixels of
    /// their glyphs in the screenshots are exactly that colour (#636366) in all
    /// three languages. Most likely the check samples the full-width heading,
    /// where a short word leaves little text to measure.
    private static let shortHeadings: Set<String> = [
        "colourSectionHeader", "locationsSectionHeader", "displaySectionHeader", "dataSectionHeader"
    ]

    /// The distance on a card's tile, CardPanel.ink on its white pill
    /// (16:1, `panelTextIsReadable`), which the right-to-left audit at the
    /// largest size reported below AA on Green Leaf Pharmacy's "0.96 mi". The
    /// audit's own screenshot of the element measures #1F1F21 on #FFFFFF.
    /// Its recording shows why: the check changes the text size as it runs,
    /// the grid switches between one column and two with it and the search
    /// field collapses, so the list is still moving as the contrast is
    /// measured. A tile's name is not this: the tile's label starts with it.
    @MainActor
    private static func isTileDistance(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let tiles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "cardRow_")).allElementsBoundByIndex
        return tiles.contains { tile in
            tile.frame.insetBy(dx: -1, dy: -1).contains(element.frame) && !tile.label.hasPrefix(element.label)
        }
    }

    /// Text on a tile that runs on under the tab bar, the last row on screen,
    /// which the Dynamic Type check calls "partially unsupported" on iOS 27
    /// at the default size: Green Leaf Pharmacy's "0.96 mi" and Nordic Nest's
    /// "0.87 mi" on the third row (y 755, the bar at 791), and at the list's
    /// end Boulder Barn Climbing's name and distance, its tile 4 pt under the
    /// bar. The same views on the rows above pass, nothing on the tile has a
    /// fixed size, and the right-to-left audit at the largest size shows
    /// every tile's name and distance grown. As the check enlarges the text
    /// the grid goes to one column, so these tiles move off the screen and it
    /// cannot see them grow.
    @MainActor
    private static func isOnTileUnderTheTabBar(_ frame: CGRect, in app: XCUIApplication) -> Bool {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.exists else { return false }
        let tiles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "cardRow_")).allElementsBoundByIndex
        return tiles.contains { tile in
            tile.frame.insetBy(dx: -1, dy: -1).contains(frame) && tile.frame.maxY > tabBar.frame.minY
        }
    }

    /// Text the contrast check measures through iOS 26's scroll edge effect,
    /// which fades what scrolls under the bars.
    @MainActor
    private static func isInScrollEdgeEffect(_ frame: CGRect, bars: [XCUIElement]) -> Bool {
        // Text partly above the top of the screen, scrolled up under the status
        // bar: Barcode Type at y −5.5 on the edit form, the Brightness Boost
        // switch's subtitle at −45 in Settings.
        if frame.minY < 0 { return true }
        // Text scrolled up between the top of the screen and the navigation
        // bar, which the bar's background covers as it reaches up behind the
        // status bar, although the bar's frame starts below it: on iOS 18.1 the
        // edit form at its end leaves Barcode Type at y 29 to 49, above a bar
        // at y 54, and the audit's own screenshot of it shows the status bar's
        // clock. It was measured only once the audit stopped measuring
        // contrast while it changed the text size, which had moved the form.
        if bars.contains(where: { $0.elementType == .navigationBar && frame.maxY <= $0.frame.minY }) { return true }
        // On iOS 26 only, text within the effect under the navigation bar and
        // above the floating tab bar: the add form's Code and its prompt 13 pt
        // below the bar and its Locations footer just above the tab bar, and
        // Delete Card 20 pt above it. The audit's own screenshots measure Code
        // #020202 on white (20.8:1), the prompt #646467 (5.9:1), the footer
        // #626265 on #F2F2F7 (5.5:1) and Delete Card #D60116 on white (5.4:1);
        // iOS 27 reports none of them.
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
            && bars.contains { $0.frame.insetBy(dx: 0, dy: -24).intersects(frame) }
    }

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
            return bars.contains { $0.frame.contains(frame) }
                || growsInFull.contains(element.identifier)
                || isInside(frame, anyOf: growsInFull.union([locationRow]), in: app)
                || isOnTileUnderTheTabBar(frame, in: app)
        case .contrast:
            // A disabled control, such as Import with nothing pasted: WCAG 1.4.3
            // exempts inactive controls.
            if !element.isEnabled { return true }
            if shortHeadings.contains(element.identifier) { return true }
            if isTileDistance(element, in: app) { return true }
            if isInScrollEdgeEffect(frame, bars: bars) { return true }
            // Text in or partly under a translucent bar is measured against the
            // bar's blur of whatever is scrolled beneath it: the camera view under
            // Add Card's bar, cards and headings under the tab bar. Pixels taken
            // from the screenshots give the accent 4.75:1 on the bar itself, and
            // CardColorTests covers every colour the app draws there.
            return bars.contains { $0.frame.intersects(frame) }
        case .textClipped:
            // An empty field's prompt (`wrappingPrompt`), which the check says
            // may be clipped at larger sizes because it is one line tall at
            // this one: German "Name, z. B. Boulder Barn" on the Add Location map.
            // It wraps in a stack that grows with it, and the AX5 captures
            // show it whole in every language.
            if element.identifier == "wrappingPrompt" { return true }
            if isInside(frame, anyOf: [locationRow], in: app) { return true }
            if isInside(frame, anyOf: wholeAtTheLargestSize, in: app) { return true }
            // The Cards tab's search field is UIKit's own, in the navigation
            // bar, which iOS sizes and collapses as the list scrolls. The
            // audit's screenshots of the report catch it part collapsed, 31 pt
            // tall rather than 36 at the default size and 10 pt at the largest,
            // and its recording shows the list moving under it as the check
            // changes the text size; the screenshot taken just before shows it
            // whole at both sizes, "Search" grown to the largest.
            if app.searchFields.allElementsBoundByIndex.contains(where: { $0.frame.intersects(frame) }) { return true }
            let tabBar = app.tabBars.firstMatch
            // The Locations footer clear of the tab bar. With a place above it,
            // German's two lines end at y 701 on the iPhone 16 Pro, 90 pt above
            // the bar, and the audit's own screenshot of the element shows both
            // lines whole at the default size.
            if element.identifier == "locationsFooter", !tabBar.exists || frame.maxY < tabBar.frame.minY - 1 {
                return true
            }
            // Text running under the tab bar before the screen is scrolled: the
            // List cuts its frame off at the bar's top edge (the Locations
            // footer ends at exactly y 791 on the iPhone 16 Pro in English and
            // Arabic alike), and the second audit, at the screen's end, sees it
            // whole. Arabic's taller lines leave more of it under the bar.
            return tabBar.exists && abs(frame.maxY - tabBar.frame.minY) < 1
        case .hitRegion:
            // MapKit's own Legal link, drawn and sized by the map.
            return app.maps.allElementsBoundByIndex.contains { $0.frame.contains(frame) }
        default:
            return false
        }
    }
}

/// The card list, a card's screen, Settings and the import sheet.
class CardsAccessibilityAuditTests: AccessibilityAuditCase {
    @MainActor
    func testCardList() throws {
        let app = launch()
        try audit(app)
        try audit(app, scrolledTo: app.buttons[SeededCard.nordicNest])
    }

    @MainActor
    func testCardDetail() throws {
        let app = launch()
        app.openCard(SeededCard.localRoast)
        try audit(app)
        try audit(app, scrolledTo: app.staticTexts["cardTimestampText"])
    }

    /// A code its format cannot draw, so the screen shows the failure message
    /// on the barcode's plate.
    @MainActor
    func testCardDetailWithFailedBarcode() throws {
        let app = launch()
        app.openCardWithFailedBarcode()
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
}

/// `CardsAccessibilityAuditTests` again right to left at the largest
/// accessibility text size.
final class CardsRightToLeftLargeTextAuditTests: CardsAccessibilityAuditTests {
    override static var variantArguments: [String] { rightToLeftAtTheLargestSize }
}

/// The Add Card and edit forms, and the Add Location map.
class CardFormAccessibilityAuditTests: AccessibilityAuditCase {
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
        app.openEditCard(SeededCard.localRoast)
        try audit(app)
        // Local Roast Coffee has a place, so this reaches a place's row and the footer.
        try audit(app, scrolledTo: app.buttons["addLocationRowButton"])
    }

    @MainActor
    func testLocationPicker() throws {
        let app = launch()
        // The seeded cards are seen from a fixed place, so no location prompt
        // comes up over the map.
        app.openLocationPicker()
        try audit(app)
    }
}

/// `CardFormAccessibilityAuditTests` again right to left at the largest
/// accessibility text size.
final class CardFormRightToLeftLargeTextAuditTests: CardFormAccessibilityAuditTests {
    override static var variantArguments: [String] { rightToLeftAtTheLargestSize }
}
