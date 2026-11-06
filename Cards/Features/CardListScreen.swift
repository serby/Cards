import SwiftData
import SwiftUI

public struct CardListScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CardItem.order) private var cardItems: [CardItem]
    @Environment(NavigationManager.self) private var navigationManager
    @Environment(LocationService.self) private var locationService
    @Environment(ArrivalScheduler.self) private var arrivalScheduler
    @Environment(\.widgetSnapshot) private var widgetSnapshot
    @AppStorage(ArrivalPlan.enabledKey) private var arrivalNotifications = true

    public init() {}

    public var body: some View {
        CardListView(
            cards: cardItems.map { item in
                CardSummary(
                    id: item.code,
                    name: item.name,
                    color: item.getColor(),
                    proximity: item.locations.proximity(to: locationService.current)
                )
            },
            actions: CardListActions(
                selectCard: { code in navigationManager.navigate(to: .card(code)) },
                addCard: { navigationManager.navigate(to: .newCard) },
                deleteCards: deleteItems,
                moveCards: moveItems
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
                CardDetailScreen(item: card, navigationManager: navigationManager)
            } else {
                Text("Card not found")
            }
        case .editCard(let code):
            if let card = findCard(by: code) {
                CardEditScreen(cardItem: card, navigationManager: navigationManager)
                    .navigationTitle("Edit Card")
            } else {
                Text("Card not found")
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
            .navigationTitle("Add Card")
        }
    }

    private func findCard(by code: String) -> CardItem? {
        cardItems.first { $0.code == code }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(cardItems[index])
            }

            cardItems.enumerated().forEach { index, item in
                item.order = index
            }
            try? modelContext.save()
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        withAnimation {
            var mutableItems = Array(cardItems)
            mutableItems.move(fromOffsets: source, toOffset: destination)

            mutableItems.enumerated().forEach { index, item in
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
