import SwiftData
import SwiftUI

public struct CardListScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CardItem.order) private var cardItems: [CardItem]
    @Environment(NavigationManager.self) private var navigationManager
    @Environment(LocationService.self) private var locationService
    @AppStorage(ArrivalNotifier.enabledKey) private var arrivalNotifications = true

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
        .task(id: watchedArrivals) {
            if arrivals.contains(where: { !$0.locations.isEmpty }) {
                locationService.start()
            }
            await ArrivalNotifier.reschedule(watchedArrivals, near: locationService.current)
        }
        .task(id: widgetCards) {
            WidgetSnapshot.publish(widgetCards)
        }
    }

    /// The cards whose barcodes go on the Lock Screen on arrival: none when the
    /// Settings switch is off, which also cancels any already scheduled.
    private var watchedArrivals: [ArrivalNotifier.Card] {
        arrivalNotifications ? arrivals : []
    }

    private var widgetCards: [WidgetCard] {
        cardItems.map(WidgetCard.init)
    }

    private var arrivals: [ArrivalNotifier.Card] {
        cardItems.map {
            ArrivalNotifier.Card(name: $0.name, code: $0.code, barcodeType: $0.getBarcodeType(), locations: $0.locations)
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
