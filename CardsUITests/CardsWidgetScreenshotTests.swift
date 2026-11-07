import XCTest

/// Captures the Home Screen widget for the App Store by adding it the way a
/// person would: long-press the Home Screen, Edit, Add Widget, Card Barcodes.
/// Run via scripts/capture-screenshots.ts, which uninstalls the app first so no
/// earlier widget is left on the Home Screen, and puts the simulator in the
/// store locale's language, so the Home Screen is in it too. SpringBoard's
/// buttons have no identifiers, so they are found by their words in that
/// language (`SpringBoardWords`).
final class CardsWidgetScreenshotTests: XCTestCase {
    /// SpringBoard's words in the simulator's language, which the capture
    /// script passes as TEST_RUNNER_SYSTEM_LANGUAGE.
    private let words = SpringBoardWords(language: ProcessInfo.processInfo.environment["SYSTEM_LANGUAGE"] ?? "en")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private var springboard: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    @MainActor
    func testCaptureWidgetScreenshot() throws {
        // The list screen writes the widget's snapshot of the seeded cards.
        let app = XCUIApplication.forTesting(["-screenshotSeed"])
        app.launch()
        XCTAssertTrue(app.buttons["addCardButton"].appears(within: 5))
        Thread.sleep(forTimeInterval: 1)

        // The snapshot is written, so the app can go. Pressing Home does not leave
        // the app on iPhone Duo's outer display, so close it and bring up SpringBoard.
        app.terminate()
        springboard.activate()
        XCTAssertTrue(springboard.wait(for: .runningForeground, timeout: 5))
        // Let the Home Screen finish animating in, or the long-press is lost.
        Thread.sleep(forTimeInterval: 1.5)
        addWidget()

        // Give the widget time to load its timeline and draw.
        Thread.sleep(forTimeInterval: 4)
        let widgets = springboard.icons
            .matching(NSPredicate(format: "identifier == %@ AND value == %@", "Card Barcodes", "Widget"))
        XCTAssertTrue(widgets.firstMatch.appears(within: 5), "The widget is not on the Home Screen")

        // A crop of the Home Screen round the widget, which leaves out the other
        // icons, the test runner's among them.
        let screenshot = XCUIScreen.main.screenshot().image
        let screen = CGRect(origin: .zero, size: screenshot.size)
        // The widget and its label with a margin of wallpaper round them. iPhone Duo
        // reports its outer display's icon frames in another space, so when no
        // widget frame is on screen, take the top of the page, where a newly added
        // widget goes, at full width.
        let band: CGRect
        if let frame = widgets.allElementsBoundByIndex.map(\.frame).first(where: { screen.contains($0) }) {
            // Little below the label: the next row of icons starts just under it.
            band = CGRect(x: frame.minX - 32, y: frame.minY - 24, width: frame.width + 64, height: frame.height + 30)
                .intersection(screen)
        } else {
            band = CGRect(x: 0, y: screen.height * 0.04, width: screen.width, height: screen.height * 0.31)
        }
        let scale = screenshot.scale
        let pixels = CGRect(x: band.minX * scale, y: band.minY * scale, width: band.width * scale, height: band.height * scale)
        let cropped = try XCTUnwrap(screenshot.cgImage?.cropping(to: pixels.integral))
        let png = try XCTUnwrap(UIImage(cgImage: cropped).pngData())

        let suffix = UIDevice.current.userInterfaceIdiom == .pad
            ? "_iPad"
            : ProcessInfo.processInfo.environment["SCREENSHOT_SUFFIX"] ?? ""
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = "05_Widget\(suffix)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func addWidget() {
        // Long-press the Home Screen to start editing. Where the empty space is
        // depends on the device, and a press that lands on an icon opens its menu,
        // whose Edit Home Screen item does the same job.
        // iPhone Duo's outer display lists Edit twice, in its side rail.
        let edit = springboard.buttons[words.edit].firstMatch
        let editHomeScreen = springboard.buttons[words.editHomeScreen].firstMatch
        for point in [CGVector(dx: 0.5, dy: 0.62), CGVector(dx: 0.5, dy: 0.8), CGVector(dx: 0.2, dy: 0.7)] where !edit.exists {
            springboard.coordinate(withNormalizedOffset: point).press(forDuration: 1.5)
            if editHomeScreen.appears(within: 2) {
                editHomeScreen.tap()
            }
            _ = edit.appears(within: 3)
        }
        if !edit.exists { attachSpringBoard("without_edit") }
        XCTAssertTrue(edit.exists, "No Edit button on the Home Screen")
        edit.tap()
        let addWidget = springboard.buttons[words.addWidget].firstMatch
        if !addWidget.appears(within: 5) { attachSpringBoard("without_add_widget") }
        XCTAssertTrue(addWidget.exists, "No Add Widget item")
        addWidget.tap()

        // The gallery's search field, whatever it is called in the language: not
        // the App Library's, which SpringBoard keeps off screen to the right.
        let search = springboard.searchFields
            .matching(NSPredicate(format: "identifier != %@", "dewey-search-field"))
            .firstMatch
        // The gallery loads every app's widgets first, which takes longer while
        // other simulators are busy, as in a parallel run.
        if !search.appears(within: 15) { attachSpringBoard("without_search") }
        XCTAssertTrue(search.exists, "No widget search field")
        search.tap()
        search.typeText("Card Barcodes")

        // The search field holds the same text, so take the match below it: the app's row.
        let matches = springboard.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Card Barcodes"))
        XCTAssertTrue(matches.firstMatch.appears(within: 5), "Card Barcodes is not in the widget gallery")
        let searchBottom = search.frame.maxY
        let result = matches.allElementsBoundByIndex.first { $0.frame.minY > searchBottom && $0.isHittable }
        XCTAssertNotNil(result, "No Card Barcodes row below the search field")
        result?.tap()

        // The gallery shows the medium size, the only one, with its own Add Widget button.
        let add = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", words.addWidget)).firstMatch
        if !add.appears(within: 5) { attachSpringBoard("without_gallery_add") }
        XCTAssertTrue(add.exists, "No Add Widget button for Card Barcodes")
        add.tap()

        let done = springboard.buttons[words.done].firstMatch
        if done.appears(within: 5) {
            done.tap()
        }
    }

    /// SpringBoard's element tree and the screen, for when a step finds nothing.
    @MainActor
    private func attachSpringBoard(_ step: String) {
        let tree = XCTAttachment(string: springboard.debugDescription)
        tree.name = "springboard_\(step)"
        tree.lifetime = .keepAlways
        add(tree)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = "screen_\(step)"
        screen.lifetime = .keepAlways
        add(screen)
    }
}

/// The words on SpringBoard's buttons that adding a widget goes through, in
/// each language a store locale captures in.
private struct SpringBoardWords {
    let edit: String
    let editHomeScreen: String
    let addWidget: String
    let done: String

    init(language: String) {
        switch language {
        case "de":
            (edit, editHomeScreen, addWidget, done) = ("Bearbeiten", "Home-Bildschirm bearbeiten", "Widget hinzufügen", "Fertig")
        case "es":
            (edit, editHomeScreen, addWidget, done) = ("Editar", "Editar pantalla de inicio", "Añadir widget", "OK")
        case "ja":
            (edit, editHomeScreen, addWidget, done) = ("編集", "ホーム画面を編集", "ウィジェットを追加", "完了")
        default:
            (edit, editHomeScreen, addWidget, done) = ("Edit", "Edit Home Screen", "Add Widget", "Done")
        }
    }
}
