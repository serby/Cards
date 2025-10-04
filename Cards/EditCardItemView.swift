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
                            .accessibilityIdentifier("nameLabel")
                        Spacer()
                        TextField("Enter name", text: $tempName)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("cardDetailsSection.nameTextField")
                            .accessibilityLabel("Card name")
                            .accessibilityHint("Enter the name of this card")
                    }
                    
                    HStack {
                        Text("Code")
                            .accessibilityIdentifier("codeLabel")
                        Spacer()
                        TextField("Enter code", text: $tempCode)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.default)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("cardDetailsSection.codeTextField")
                            .accessibilityLabel("Card code")
                            .accessibilityHint("Enter the barcode number for this card")
                    }
                }
                .accessibilityIdentifier("cardDetailsSection")
                
                Section {
                    Picker("Barcode Type", selection: $selectedType) {
                        ForEach(BarcodeType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type.rawValue)
                                .accessibilityIdentifier("barcodeType_\(type.rawValue.replacingOccurrences(of: " ", with: "_"))")
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("barcodeTypePicker")
                    .accessibilityLabel("Barcode type")
                    .accessibilityHint("Select the type of barcode for this card")
                }
                .accessibilityIdentifier("barcodeTypeSection")
            }
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("editCardForm")
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
                    .accessibilityLabel("Save card")
                    .accessibilityHint("Save changes to this card")
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancelButton")
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Discard changes and return to previous screen")
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
