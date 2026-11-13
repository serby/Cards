import SwiftUI
import UserNotifications

/// The Card Barcodes app on Apple Watch (spec/watch.md), and its composition
/// root: the cards and the navigation are made here, once, and the
/// notification and WatchConnectivity delegates handed to the system.
@main
struct CardsWatchApp: App {
    @State private var cards: WatchCards
    @State private var navigation: WatchNavigation
    private let phone: PhoneLink
    private let arrivalRouter: ArrivalNotificationRouter

    init() {
        let cards = WatchCards(file: .live)
        let navigation = WatchNavigation()
        _cards = State(initialValue: cards)
        _navigation = State(initialValue: navigation)
        // An arrival notification from the iPhone, tapped on the watch, opens
        // the watch app on its card (WATCH-5). Set before launch finishes, so a
        // tap that launched the app is not missed.
        arrivalRouter = ArrivalNotificationRouter { code in
            navigation.open(code)
        }
        UNUserNotificationCenter.current().delegate = arrivalRouter
        phone = PhoneLink { encoded, sentAt in
            cards.receive(encoded, sentAt: sentAt)
        }
        phone.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchCardsScreen()
                .environment(cards)
                .environment(navigation)
                .environment(\.distanceUnits, cards.distanceUnits)
                .tint(.accent)
        }
    }
}
