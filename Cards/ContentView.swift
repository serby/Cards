import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CardItem.order) private var cardItems: [CardItem]
    @State private var isShowingScanner = false
    @State private var scannedCode: String?
    @State private var barcodeType: BarcodeType?
    @State private var isAddingCard = false
    @State private var isEditing = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(cardItems) { item in
                    NavigationLink {
                        CardItemView(item: item)
                    } label: {
                        Text(item.name).padding(.vertical)
                    }
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItems)
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { isAddingCard = true }) {
                        Label("Add Card", systemImage: "plus")
                            .accessibilityIdentifier("addCardButton")
                    }
                    Button(action: { isShowingScanner = true }) {
                        Label("Scan Code", systemImage: "camera")
                            .accessibilityIdentifier("scanCodeButton")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingCard) {
            NavigationStack {
                let newCardItem = CardItem(timestamp: Date(), code: "", name: "")
                EditCardItemView(cardItem: newCardItem, onSave: { updatedCard in
                    modelContext.insert(updatedCard)
                })
                .navigationTitle("Add Card")
            }
        }
        .sheet(isPresented: $isShowingScanner) {
            CameraScannerView(scannedCode: $scannedCode, barcodeType: $barcodeType)
        }
        .onChange(of: scannedCode) {
            if let safeScannedCode = scannedCode {
                withAnimation {
                    let newItem = CardItem(timestamp: Date(), code: safeScannedCode, name: safeScannedCode, barcodeType: barcodeType)
                    modelContext.insert(newItem)
                    scannedCode = nil
                }
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
            // Save changes to SwiftData
            try? modelContext.save()
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        withAnimation {
            var mutableItems = Array(cardItems)
            mutableItems.move(fromOffsets: source, toOffset: destination)
            
            // Update order property directly on SwiftData objects
            mutableItems.enumerated().forEach { index, item in
                item.order = index
            }
            
            // Save changes to SwiftData
            try? modelContext.save()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: CardItem.self, inMemory: true)
}
