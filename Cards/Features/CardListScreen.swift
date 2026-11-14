import StoreKit
import SwiftData
import SwiftUI

public struct CardListScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CardItem.order) private var cardItems: [CardItem]
    @Environment(NavigationManager.self) private var navigationManager
    @Environment(LocationService.self) private var locationService
    @Environment(ArrivalScheduler.self) private var arrivalScheduler
    @Environment(\.widgetSnapshot) private var widgetSnapshot
    @Environment(\.watchSync) private var watchSync
    @Environment(\.telemetry) private var telemetry
    @Environment(\.distanceUnits) private var distanceUnits
    @Environment(\.requestReview) private var requestReview
    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    /// With Reduce Motion on, cards open without zooming (CARD-4).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where card screens zoom up out of: the tiles and the card for where you are.
    @Namespace private var cardZoom
    /// What the card being opened from here zooms out of, until its screen
    /// takes it. Nil for a card opened from anywhere else, which slides in.
    @State private var opening: CardZoomSource?
    @AppStorage(ArrivalPlan.enabledKey) private var arrivalNotifications = true
    @AppStorage(DeviceSettings.cardSortOrderKey) private var sortOrder = CardSortOrder.custom
    @AppStorage(DeviceSettings.showsCardWhereYouAreKey) private var showsCardWhereYouAre = false
    @AppStorage(DeviceSettings.reviewPromptKey) private var reviewPrompt = ReviewPrompt()
    @State private var search = ""
    /// Whether the screen on top of the list is a card rather than the edit
    /// form, so that coming back to the list from it is a moment to ask for a
    /// rating (PLAT-8). Deleting a card from its edit form is not.
    @State private var cardOnTop = false
    /// The pause before asking for a rating after coming back from a card, so
    /// it can be called off if the list goes away first.
    @State private var reviewRequest: Task<Void, Never>?
    /// Read once: the version cannot change while the app runs.
    private static let appVersion = Bundle.main.marketingVersion ?? ""

    public init() {}

    public var body: some View {
        CardListView(
            cards: CardArrangement.arranged(cardItems, by: sortOrder, search: search, near: locationService.current)
                .map(summary),
            cardHere: cardHere.map(detail),
            search: $search,
            sortOrder: $sortOrder,
            zoom: cardZoom,
            actions: CardListActions(
                selectCard: { code in open(code, from: .tile) },
                selectCardWhereYouAre: { code in open(code, from: .cardWhereYouAre) },
                editCard: { code in navigationManager.navigate(to: .editCard(code)) },
                addCard: { navigationManager.navigate(to: .newCard) },
                deleteCard: deleteCard,
                moveCard: moveCard
            )
        )
        .navigationDestination(for: NavigationRoute.self) { route in
            destinationView(for: route)
        }
        // Again when the cards change and as you move, so the nearest places are the ones watched.
        .task(id: ArrivalWatch(cards: watchedArrivals, area: ArrivalPlan.area(of: locationService.current))) {
            if arrivals.contains(where: { !$0.locations.isEmpty }) {
                locationService.start()
            }
            await arrivalScheduler.reschedule(watchedArrivals, near: locationService.current)
        }
        .task(id: widgetCards) {
            widgetSnapshot.write(widgetCards)
        }
        // The barcodes are drawn for the watch only when what it shows changes (WATCH-1).
        .task(id: WatchContents(cards: widgetCards, icons: cardItems.map(\.icon), distanceUnits: distanceUnits)) {
            let snapshot = telemetry.measure(.watchSnapshot) {
                WatchSnapshot(cards: cardItems.map(WatchCard.init), distanceUnits: distanceUnits)
            }
            watchSync.send(snapshot)
        }
        .onAppear { telemetry.record(.screen(.cards)) }
        .onChange(of: navigationManager.navigationPath.isEmpty) { _, isEmpty in
            guard isEmpty else { return }
            if cardOnTop {
                askForReviewAfterPause()
            }
            cardOnTop = false
        }
        // Opening another card or switching tabs during the pause calls it off.
        .onDisappear {
            reviewRequest?.cancel()
        }
    }

    /// Waits a moment after coming back from a card, then asks for a rating if
    /// it is due. A one-off task rather than `.task(id:)`, which would run again
    /// each time the list reappears, as on switching back to the Cards tab.
    private func askForReviewAfterPause() {
        reviewRequest?.cancel()
        reviewRequest = Task {
            do {
                try await Task.sleep(for: ReviewPrompt.pause)
            } catch {
                return
            }
            askForReviewIfDue()
        }
    }

    /// A card's screen has appeared, so a card is on top and today counts
    /// towards asking for a rating (PLAT-8).
    private func cardShown() {
        cardOnTop = true
        guard DevelopmentHooks.asksForReviews else { return }
        reviewPrompt.recordCardShown(at: .now, version: Self.appVersion, calendar: calendar)
    }

    /// Asks for an App Store rating once it is due (PLAT-8), and only while the
    /// list is all that shows: no card, sheet or search over it, and the app in
    /// front. Apple decides whether its prompt actually appears.
    private func askForReviewIfDue() {
        guard DevelopmentHooks.asksForReviews,
              reviewPrompt.isDue(in: Self.appVersion),
              navigationManager.tab == .cards,
              navigationManager.navigationPath.isEmpty,
              navigationManager.sharedCard == nil,
              !CardArrangement.isFiltering(search),
              scenePhase == .active
        else { return }
        reviewPrompt.recordAsked(in: Self.appVersion)
        requestReview()
    }

    /// The card to show in full above the grid, when the Settings switch is on
    /// and you are inside one of its places (SET-3). Not while searching, when
    /// you are looking for another card.
    private var cardHere: CardItem? {
        guard showsCardWhereYouAre, !CardArrangement.isFiltering(search) else { return nil }
        return CardArrangement.cardHere(in: cardItems, at: locationService.current)
    }

    private func summary(_ item: CardItem) -> CardSummary {
        CardSummary(
            id: item.code,
            name: item.name,
            color: item.getColor(),
            proximity: item.locations.proximity(to: locationService.current),
            icon: item.icon
        )
    }

    private func detail(_ item: CardItem) -> CardDetail {
        CardDetail(item, near: locationService.current)
    }

    /// The cards that remind you on arrival: none when the Settings switch is
    /// off, which also cancels any already scheduled. Each card's own switch is
    /// applied when the arrivals are planned.
    private var watchedArrivals: [ArrivalPlan.Card] {
        arrivalNotifications ? arrivals : []
    }

    private var widgetCards: [WidgetCard] {
        cardItems.map(WidgetCard.init)
    }

    private var arrivals: [ArrivalPlan.Card] {
        cardItems.map {
            ArrivalPlan.Card(
                name: $0.name,
                code: $0.code,
                barcodeType: $0.getBarcodeType(),
                locations: $0.locations,
                notifies: $0.notifiesOnArrival
            )
        }
    }

    @ViewBuilder
    private func destinationView(for route: NavigationRoute) -> some View {
        switch route {
        case .cards:
            EmptyView()
        case .card(let code):
            if let card = findCard(by: code) {
                ZoomingDestination(source: zoomSource(for: code), in: cardZoom) {
                    CardDetailScreen(item: card, navigationManager: navigationManager)
                        .onAppear(perform: cardShown)
                }
                // Taken, so the next card opened from a notification, the widget,
                // a link or a save slides in.
                .onAppear { opening = nil }
            } else {
                Text("Card not found", comment: "Shown when a link or notification opens a card that has since been deleted.")
            }
        case .editCard(let code):
            if let card = findCard(by: code) {
                CardEditScreen(cardItem: card, navigationManager: navigationManager)
                    .navigationTitle(Text("Edit Card", comment: "Title of the form for changing an existing card."))
                    .onAppear { cardOnTop = false }
            } else {
                Text("Card not found", comment: "Shown when a link or notification opens a card that has since been deleted.")
            }
        case .newCard:
            CardEditScreen(
                cardItem: CardItem(
                    timestamp: Date(),
                    code: "",
                    name: "",
                    barcodeType: nil
                ),
                navigationManager: navigationManager,
                onSave: { updatedCard in
                    // New cards go at the end of the list.
                    updatedCard.order = CardItem.nextOrder(after: cardItems)
                    modelContext.insert(updatedCard)
                    navigationManager.navigate(to: .card(updatedCard.code))
                }
            )
            .navigationTitle(Text("Add Card", comment: "Title of the form for adding a new card."))
            .onAppear { cardOnTop = false }
        }
    }

    /// Opens the card with `code`, zooming up out of `kind` of source.
    private func open(_ code: String, from kind: CardZoomSource.Kind) {
        telemetry.record(.cardOpened(kind == .tile ? .grid : .cardWhereYouAre))
        opening = CardZoomSource(kind, cardID: code)
        navigationManager.navigate(to: .card(code))
    }

    /// What the card screen for `code` zooms out of: the source it was opened
    /// from here, or nil when it was opened from anywhere else or with Reduce
    /// Motion on, so it slides in.
    private func zoomSource(for code: String) -> CardZoomSource? {
        guard !reduceMotion, let opening, opening.cardID == code else { return nil }
        return opening
    }

    private func findCard(by code: String) -> CardItem? {
        cardItems.first { $0.code == code }
    }

    private func deleteCard(code: String) {
        guard let card = findCard(by: code) else { return }
        withAnimation {
            modelContext.delete(card)
            // The rest keep their order, renumbered from 0.
            CardItem.renumber(cardItems.filter { $0 !== card })
            try? modelContext.save()
        }
    }

    /// Puts the card with `code` where the card with `target` is, in custom order.
    private func moveCard(code: String, onto target: String) {
        guard let source = cardItems.firstIndex(where: { $0.code == code }),
              let destination = cardItems.firstIndex(where: { $0.code == target })
        else { return }
        withAnimation {
            CardArrangement.moving(cardItems, from: source, to: destination).enumerated().forEach { index, item in
                item.order = index
            }
            try? modelContext.save()
        }
    }
}

/// What the arrival schedule depends on, so it is planned again only when that changes.
private struct ArrivalWatch: Hashable {
    let cards: [ArrivalPlan.Card]
    // swiftlint:disable:next discouraged_optional_collection
    let area: [Int]?
}

/// What the Apple Watch is sent (WATCH-1), so it is sent again only when that
/// changes: the widget's copy of each card, plus its icon and the Distances choice.
private struct WatchContents: Hashable {
    let cards: [WidgetCard]
    let icons: [String?]
    let distanceUnits: DistanceUnits
}

/// A card's screen that zooms up out of `source` as it opens, and back into
/// it as it goes, by Back or a swipe (CARD-4), or slides in without one. The
/// source is fixed when the screen is made, so the screen never changes
/// between the two while it shows, which would make it anew.
private struct ZoomingDestination<Content: View>: View {
    @State private var source: CardZoomSource?
    private let namespace: Namespace.ID
    private let content: Content

    init(source: CardZoomSource?, in namespace: Namespace.ID, @ViewBuilder content: () -> Content) {
        _source = State(initialValue: source)
        self.namespace = namespace
        self.content = content()
    }

    var body: some View {
        if let source {
            content.navigationTransition(.zoom(sourceID: source, in: namespace))
        } else {
            content
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CardListScreen()
            .environment(NavigationManager())
            .environment(LocationService())
            .environment(ArrivalScheduler(notifications: .silent))
            .environment(\.placeSearch, .sample)
    }
    .modelContainer(for: CardItem.self, inMemory: true)
}
#endif
