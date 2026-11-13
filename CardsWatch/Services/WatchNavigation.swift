import Foundation
import Observation

/// Which card's screen the watch shows, by its code, over the list. Created
/// once by `CardsWatchApp`, so an arrival notification tapped on the watch
/// (WATCH-5) and arriving at a place (WATCH-4) open a card the same way.
@MainActor
@Observable
final class WatchNavigation {
    /// The cards on top of the list, by code: empty for the list, one for a card.
    var path: [String] = []

    /// When a tapped notification last opened a card, so the card for where
    /// you are does not replace it straight after (WATCH-5).
    private(set) var openedFromNotificationAt: Date?

    /// Shows the card with `code`, in place of whatever was on top of the list.
    func open(_ code: String) {
        path = [code]
    }

    /// Shows the card a tapped notification is for.
    func openFromNotification(_ code: String) {
        open(code)
        openedFromNotificationAt = .now
    }

    /// Whether a notification opened a card within the last minute, as the app
    /// came forward for it.
    func justOpenedFromNotification(now: Date = .now) -> Bool {
        openedFromNotificationAt.map { now.timeIntervalSince($0) < 60 } ?? false
    }
}
