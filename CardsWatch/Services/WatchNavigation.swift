import Observation

/// Which card's screen the watch shows, by its code, over the list. Created
/// once by `CardsWatchApp`, so an arrival notification tapped on the watch
/// (WATCH-5) and arriving at a place (WATCH-4) open a card the same way.
@MainActor
@Observable
final class WatchNavigation {
    /// The cards on top of the list, by code: empty for the list, one for a card.
    var path: [String] = []

    /// Shows the card with `code`, in place of whatever was on top of the list.
    func open(_ code: String) {
        path = [code]
    }
}
