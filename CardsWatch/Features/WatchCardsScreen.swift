import CoreLocation
import SwiftUI

/// The watch app's one connector: the cards, where the watch is and the
/// navigation in, the list and the card screens out. Each time the app opens
/// or comes to the front it finds where the watch is, for the list's
/// distances, and opens the card for the place you are at, once per arrival
/// (WATCH-4).
struct WatchCardsScreen: View {
    @Environment(WatchCards.self) private var cards
    @Environment(WatchNavigation.self) private var navigation
    @Environment(\.watchLocation) private var watchLocation
    @Environment(\.scenePhase) private var scenePhase
    /// Where the watch was last found, or nil until it has been.
    @State private var location: CLLocation?
    /// The arrival a card was last opened for, kept on the watch, as watchOS
    /// often ends the app while it is in the background (WATCH-4).
    @AppStorage(WatchArrival.storageKey) private var keptArrival = ""

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.path) {
            WatchCardListView(cards: cards.cards.map(summary))
                .navigationDestination(for: String.self) { code in
                    if let card = cards.card(code) {
                        WatchCardView(card: card)
                    } else {
                        Text("Card not found", comment: "Shown on Apple Watch when a notification opens a card that is no longer on the watch.")
                    }
                }
        }
        // Again on every return to the front; leaving it cancels a wait for a fix.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await openTheCardWhereYouAre()
        }
    }

    /// Finds the watch, then opens the card for the place it is at, unless
    /// that card was opened for this arrival already, a notification has just
    /// opened one, or you opened another while waiting for the fix.
    private func openTheCardWhereYouAre() async {
        let shownBefore = navigation.path
        guard let found = await watchLocation.current(), !Task.isCancelled else { return }
        location = found
        var arrivals = WatchArrivals(current: WatchArrival(stored: keptArrival))
        let code = arrivals.cardToOpen(in: cards.cards, at: found)
        keptArrival = arrivals.current?.stored ?? ""
        guard let code, navigation.path == shownBefore, !navigation.justOpenedFromNotification() else { return }
        navigation.open(code)
    }

    private func summary(_ card: WatchCard) -> WatchCardSummary {
        WatchCardSummary(id: card.code, name: card.name, color: card.color, icon: card.icon, proximity: card.proximity(to: location))
    }
}

#if DEBUG
#Preview("Cards") {
    WatchCardsScreen()
        .environment(WatchCards.preview(WatchCard.samples))
        .environment(WatchNavigation())
        .environment(\.watchLocation, .fixed(nil))
}

#Preview("At Boulder Barn") {
    WatchCardsScreen()
        .environment(WatchCards.preview(WatchCard.samples))
        .environment(WatchNavigation())
        .environment(\.watchLocation, .fixed(WatchCard.atBoulderBarn))
}

#Preview("No cards yet") {
    WatchCardsScreen()
        .environment(WatchCards.preview([]))
        .environment(WatchNavigation())
        .environment(\.watchLocation, .fixed(nil))
}
#endif
