import XCTest

/// Whether `condition` holds now or within `timeout` seconds, looking at once
/// and then every tenth of a second. XCTest's own waits
/// (`waitForExistence(timeout:)`, `waitForNonExistence(timeout:)` and
/// `XCTNSPredicateExpectation`) first look after a full second, so each cost
/// a second even when what it waited for was already there: 110 waits in the
/// first third of the suite, every one at least a second. The UI tests use
/// these instead. A wait is for something that is coming, never a pause: what
/// a test waits for is there, or the test fails, except where a test checks
/// that something does not happen, such as the keyboard staying down, and
/// says so.
@MainActor
func eventually(within timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while true {
        if condition() { return true }
        let now = Date()
        if now >= deadline { return false }
        RunLoop.current.run(until: min(deadline, now.addingTimeInterval(0.1)))
    }
}

@MainActor
extension XCUIElement {
    /// Whether the element is there now or within `timeout` seconds.
    func appears(within timeout: TimeInterval = 5) -> Bool {
        eventually(within: timeout) { exists }
    }

    /// Whether the element has gone now or within `timeout` seconds.
    func disappears(within timeout: TimeInterval = 3) -> Bool {
        eventually(within: timeout) { !exists }
    }

    /// Whether the element matches `predicate`, such as `label == "Copied"`,
    /// now or within `timeout` seconds.
    func matches(_ predicate: NSPredicate, within timeout: TimeInterval = 5) -> Bool {
        eventually(within: timeout) { predicate.evaluate(with: self) }
    }
}

/// Helpers every UI test class shares.
extension XCTestCase {
    @MainActor
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.appears(within: timeout)
    }

    /// Waits for a field to hold `value`, as one MapKit fills in does.
    @MainActor
    func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval = 5) -> Bool {
        element.matches(NSPredicate(format: "value == %@", value), within: timeout)
    }

    /// Launches with the six screenshot cards, in custom order, without the
    /// card for where you are and with Automatic distances, whatever an earlier
    /// run left in those settings, and in the suite's variant, such as right to
    /// left, where it has one.
    @MainActor
    func launchWithSeededCards() -> XCUIApplication {
        let variant = (self as? CardsUITestCase).map { type(of: $0).variantArguments } ?? []
        let app = XCUIApplication.forTesting([
            "-screenshotSeed", "-cardSortOrder", "custom", "-showsCardWhereYouAre", "NO", "-distanceUnits", "automatic"
        ] + variant)
        app.launch()
        return app
    }

    /// A card's tile. Its label starts with the card name and goes on to say how
    /// far away the card is.
    @MainActor
    func tile(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }
}
