import XCTest

/// Captures the Home Screen widget for the App Store by adding it the way a
/// person would: long-press the Home Screen, Edit, Add Widget, Card Barcodes.
/// Run via scripts/capture-screenshots.sh, which uninstalls the app first so no
/// earlier widget is left on the Home Screen.
final class CardsWidgetScreenshotTests: XCTestCase {
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
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-screenshotSeed"]
        app.launch()
        XCTAssertTrue(app.buttons["addCardButton"].waitForExistence(timeout: 5))
        let permission = springboard.alerts.firstMatch
        if permission.waitForExistence(timeout: 5) {
            permission.buttons.element(boundBy: 1).tap()
        }
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
        XCTAssertTrue(widgets.firstMatch.waitForExistence(timeout: 5), "The widget is not on the Home Screen")

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
        let edit = springboard.buttons["Edit"].firstMatch
        let editHomeScreen = springboard.buttons["Edit Home Screen"].firstMatch
        for point in [CGVector(dx: 0.5, dy: 0.62), CGVector(dx: 0.5, dy: 0.8), CGVector(dx: 0.2, dy: 0.7)] where !edit.exists {
            springboard.coordinate(withNormalizedOffset: point).press(forDuration: 1.5)
            if editHomeScreen.waitForExistence(timeout: 2) {
                editHomeScreen.tap()
            }
            _ = edit.waitForExistence(timeout: 3)
        }
        if !edit.exists {
            let tree = XCTAttachment(string: springboard.debugDescription)
            tree.name = "springboard_without_edit"
            tree.lifetime = .keepAlways
            add(tree)
            let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screen.name = "screen_without_edit"
            screen.lifetime = .keepAlways
            add(screen)
        }
        XCTAssertTrue(edit.exists, "No Edit button on the Home Screen")
        edit.tap()
        let addWidget = springboard.buttons["Add Widget"].firstMatch
        XCTAssertTrue(addWidget.waitForExistence(timeout: 5), "No Add Widget item")
        addWidget.tap()

        let search = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR placeholderValue == %@", "Search Widgets", "Search Widgets"))
            .firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "No widget search field")
        search.tap()
        search.typeText("Card Barcodes")

        // The search field holds the same text, so take the match below it: the app's row.
        let matches = springboard.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Card Barcodes"))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 5), "Card Barcodes is not in the widget gallery")
        let searchBottom = search.frame.maxY
        let result = matches.allElementsBoundByIndex.first { $0.frame.minY > searchBottom && $0.isHittable }
        XCTAssertNotNil(result, "No Card Barcodes row below the search field")
        result?.tap()

        // The gallery shows the medium size, the only one, with its own Add Widget button.
        let add = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Add Widget")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), "No Add Widget button for Card Barcodes")
        add.tap()

        let done = springboard.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 5) {
            done.tap()
        }
    }
}
