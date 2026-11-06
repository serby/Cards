import XCTest

/// Helpers every UI test class shares.
extension XCTestCase {
    @MainActor
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    /// Launches with the six screenshot cards, in custom order and without the
    /// card for where you are, whatever an earlier run left in those settings.
    @MainActor
    func launchWithSeededCards() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-screenshotSeed", "-cardSortOrder", "custom", "-showsCardWhereYouAre", "NO"]
        app.launch()
        dismissNotificationPrompt()
        return app
    }

    /// A card's tile. Its label starts with the card name and goes on to say how
    /// far away the card is.
    @MainActor
    func tile(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    /// Cards with locations ask for notifications once; answer so the alert
    /// does not cover the app.
    @MainActor
    func dismissNotificationPrompt() {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 5) {
            alert.buttons.element(boundBy: 1).tap()
        }
    }
}
