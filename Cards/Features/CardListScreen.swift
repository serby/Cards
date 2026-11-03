import SwiftData
import SwiftUI

public struct CardListScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CardItem.order) private var cardItems: [CardItem]
    @Environment(NavigationManager.self) private var navigationManager
    @Environment(LocationService.self) private var locationService

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
        .task(id: arrivals) {
            if arrivals.contains(where: { !$0.locations.isEmpty }) {
                locationService.start()
            }
            await ArrivalNotifier.reschedule(arrivals, near: locationService.current)
        }
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

#Preview {
    NavigationStack {
        CardListScreen()
            .environment(NavigationManager())
            .environment(LocationService())
    }
    .modelContainer(for: CardItem.self, inMemory: true)
}
