import SwiftData
import SwiftUI

extension Notification.Name {
    static let deepLink = Notification.Name("deepLink")
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CardItem.order) private var cardItems: [CardItem]
    @StateObject private var deepLinkManager = DeepLinkManager()
    @State private var scannedCode: String?
    @State private var barcodeType: BarcodeType?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(cardItems) { item in
                    NavigationLink {
                        CardItemView(item: item)
                    } label: {
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
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        deepLinkManager.activeSheet = .addCard
                    }) {
                        Label("Add Card", systemImage: "plus")
                            .accessibilityIdentifier("addCardButton")
                    }
                    Button(action: {
                        deepLinkManager.activeSheet = .camera
                    }) {
                        Label("Scan Code", systemImage: "camera")
                            .accessibilityIdentifier("scanCodeButton")
                    }
                }
            }
        }
        .sheet(item: $deepLinkManager.activeSheet) { sheet in
            switch sheet {
            case .addCard:
                NavigationStack {
                    let newCardItem = CardItem(timestamp: Date(), code: "", name: "")
                    EditCardItemView(cardItem: newCardItem, onSave: { updatedCard in
                        modelContext.insert(updatedCard)
                        deepLinkManager.activeSheet = nil
                    })
                    .navigationTitle("Add Card")
                }
            case .camera:
                CameraScannerView(scannedCode: $scannedCode, barcodeType: $barcodeType)
            case .editCard(let card):
                NavigationStack {
                    EditCardItemView(cardItem: card, onSave: { _ in
                        deepLinkManager.activeSheet = nil
                    })
                    .navigationTitle("Edit Card")
                }
            }
        }
        .onChange(of: scannedCode) {
            if let safeScannedCode = scannedCode {
                withAnimation {
                    let newItem = CardItem(timestamp: Date(), code: safeScannedCode, name: safeScannedCode, barcodeType: barcodeType)
                    modelContext.insert(newItem)
                    scannedCode = nil
                    deepLinkManager.activeSheet = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLink)) { notification in
            if let url = notification.object as? URL {
                deepLinkManager.handleDeepLink(url, modelContext: modelContext)
            }
        }
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
