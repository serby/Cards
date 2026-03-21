import CardsCore
import CardsUI
import SwiftData
import SwiftUI

struct CardRow: View {
    @Environment(NavigationManager.self) private var navigationManager
    @State private var trigger: Bool = false
    private var cardItem: CardItem
    init(cardItem: CardItem) {
        self.cardItem = cardItem
    }
    
    var body: some View {
        Button {
            trigger.toggle()
            navigationManager.navigate(to: NavigationRoute.card(cardItem.code))
        } label: {
            Text(cardItem.name)
                .padding(.vertical)
                .foregroundColor(.primaryText)
        }
        .sensoryFeedback(trigger: trigger, { SensoryFeedback.impact(weight: .heavy) })
    }
}

public struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CardItem.order) private var cardItems: [CardItem]
    @Environment(NavigationManager.self) private var navigationManager
    @State var searchText: String = ""
    @State var searchable: Bool = false
    @State private var toolbarVisible = true
    
    public init() {}
    
    public var body: some View {
        List {
            ForEach(cardItems) { item in
                CardRow(cardItem: item)
                    .listRowBackground(Color.clear)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .onDelete(perform: deleteItems)
            .onMove(perform: moveItems)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.primaryBackground)
        .navigationTitle("Cards")
        .toolbar(toolbarVisible ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    navigationManager.navigate(to: .newCard)
                } label: {
                    Image(systemName: "barcode.viewfinder")
                }
                .foregroundColor(.accent)
                .accessibilityIdentifier("addCardButton")
                .accessibilityLabel("Add Card")
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                toolbarVisible = newValue <= 0
            }
        }
        .navigationDestination(for: NavigationRoute.self) { route in
            destinationView(for: route)
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: NavigationRoute) -> some View {
        switch route {
        case .cards:
            EmptyView()
        case .card(let code):
            if let card = findCard(by: code) {
                CardItemView(item: card, navigationManager: navigationManager)
            } else {
                Text("Card not found")
            }
        case .editCard(let code):
            if let card = findCard(by: code) {
                EditCardItemView(cardItem: card, navigationManager: navigationManager)
                    .navigationTitle("Edit Card")
            } else {
                Text("Card not found")
            }
        case .newCard:
            EditCardItemView(
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
        return cardItems.first { $0.code == code }
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
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
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
    CardListView()
        .modelContainer(for: CardItem.self, inMemory: true)
}
