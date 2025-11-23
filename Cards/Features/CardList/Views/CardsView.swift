import SwiftData
import SwiftUI

struct CardRow: View {
    @EnvironmentObject private var navigationManager: NavigationManager
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
                .foregroundColor(.primary)
        }
        .sensoryFeedback(trigger: trigger, { SensoryFeedback.impact(weight: .heavy) })
    }
}

struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CardItem.order) private var cardItems: [CardItem]
    @EnvironmentObject private var navigationManager: NavigationManager
    @State private var scannedCode: String?
    @State private var barcodeType: BarcodeType?
    @State var searchText: String = ""
    @State var searchable: Bool = false
    var body: some View {
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
        .background(.ultraThinMaterial)
        .navigationTitle("Cards")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        navigationManager.navigate(to: .newCard)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addCardButton")
                    .accessibilityLabel("Add Card")
                    
                    Button {
                        navigationManager.navigate(to: .camera)
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                    .accessibilityIdentifier("scanCodeButton")
                    .accessibilityLabel("Scan Code")
                }
            }
        }
        .navigationDestination(for: NavigationRoute.self) { route in
            destinationView(for: route)
        }
//        .conditionalModifier { view in
//            if searchable {
//                view.searchable(
//                    text: $searchText,
//                    placement: .automatic,
//                    prompt: "Type here to search"
//                )
//            } else {
//                view
//            }
//        }
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
                cardItem: CardItem(timestamp: Date(), code: "", name: ""),
                navigationManager: navigationManager,
                onSave: { updatedCard in
                    modelContext.insert(updatedCard)
                    navigationManager.navigate(to: .card(updatedCard.code))
                }
            )
            .navigationTitle("Add Card")
        case .camera:
            CameraScannerView(scannedCode: $scannedCode, barcodeType: $barcodeType)
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
