import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CardItem.order) private var cardItems: [CardItem]
    @EnvironmentObject private var navigationManager: NavigationManager
    @State private var scannedCode: String?
    @State private var barcodeType: BarcodeType?
    
    var body: some View {
        NavigationStack(path: $navigationManager.navigationPath) {
            List {
                ForEach(cardItems) { item in
                    NavigationLink(value: NavigationRoute.card(item.code)) {
                        Text(item.name)
                            .padding(.vertical)
                            .foregroundColor(.primary)
                    }
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
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        navigationManager.navigate(to: .newCard)
                    }) {
                        Label("Add Card", systemImage: "plus")
                            .accessibilityIdentifier("addCardButton")
                    }
                    Button(action: {
                        navigationManager.navigate(to: .camera)
                    }) {
                        Label("Scan Code", systemImage: "camera")
                            .accessibilityIdentifier("scanCodeButton")
                    }
                }
            }
            .navigationDestination(for: NavigationRoute.self) { route in
                destinationView(for: route)
            }
        }
        .onChange(of: scannedCode) {
            if let safeScannedCode = scannedCode {
                withAnimation {
                    let newItem = CardItem(timestamp: Date(), code: safeScannedCode, name: safeScannedCode, barcodeType: barcodeType)
                    modelContext.insert(newItem)
                    scannedCode = nil
                    navigationManager.navigate(to: .cards)
                }
            }
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
                cardItem: CardItem(timestamp: Date(), code: "", name: ""),
                navigationManager: navigationManager,
                onSave: { updatedCard in
                    modelContext.insert(updatedCard)
                    navigationManager.navigate(to: .cards)
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
    ContentView()
        .modelContainer(for: CardItem.self, inMemory: true)
}
