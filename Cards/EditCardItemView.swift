import SwiftUI

struct EditCardItemView: View {
    @Environment(\.dismiss) var dismiss
    
    private var cardItem: CardItem
    @State private var tempName: String
    @State private var tempCode: String
    @State private var selectedType: String
    
    var onSave: ((CardItem) -> Void)? // Closure to be called on save
    
    init(cardItem: CardItem, onSave: ((CardItem) -> Void)? = nil) {
        self.cardItem = cardItem
        _tempName = State(initialValue: cardItem.name)
        _tempCode = State(initialValue: cardItem.code)
        _selectedType = State(initialValue: cardItem.type ?? BarcodeType.code128.rawValue)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Enter name", text: $tempName)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                    }
                    
                    HStack {
                        Text("Code")
                        Spacer()
                        TextField("Enter code", text: $tempCode)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.default)
                            .autocorrectionDisabled()
                    }
                }
                
                Section {
                    Picker("Barcode Type", selection: $selectedType) {
                        ForEach(BarcodeType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type.rawValue)
                        }
                    }
                    .pickerStyle(.menu)  // Choose your preferred style
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        self.cardItem.name = tempName
                        self.cardItem.code = tempCode
                        self.cardItem.type = selectedType
                        onSave?(self.cardItem)
                        dismiss()
                    }
                    .accessibilityIdentifier("saveCardButton")
                }
            }
        }
    }
}

#Preview {
    let sampleCardItem = CardItem(timestamp: Date(), code: "123ABC", name: "Westway", barcodeType: BarcodeType.code128)
    EditCardItemView(cardItem: sampleCardItem, onSave: { updatedItem in
        print("Saved item: \(updatedItem)")
    })
}
