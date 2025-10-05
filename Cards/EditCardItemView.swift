import SwiftUI

struct EditCardItemView: View {
    private var cardItem: CardItem
    @State private var tempName: String
    @State private var tempCode: String
    @State private var selectedType: String
    
    let navigationManager: NavigationManager?
    var onSave: ((CardItem) -> Void)? // Closure to be called on save
    
    init(cardItem: CardItem, navigationManager: NavigationManager? = nil, onSave: ((CardItem) -> Void)? = nil) {
        self.cardItem = cardItem
        self.navigationManager = navigationManager
        _tempName = State(initialValue: cardItem.name)
        _tempCode = State(initialValue: cardItem.code)
        _selectedType = State(initialValue: cardItem.type ?? BarcodeType.code128.rawValue)
        self.onSave = onSave
    }
    
    var body: some View {
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
                    cardItem.name = tempName
                    cardItem.code = tempCode
                    cardItem.type = selectedType
                    
                    if let onSave = onSave {
                        onSave(cardItem)
                    } else {
                        navigationManager?.navigate(to: .card(cardItem.code))
                    }
                }
                .accessibilityIdentifier("saveCardButton")
                .accessibilityLabel("Save card")
                .accessibilityHint("Save changes to this card")
            }
        }
    }
}

#Preview {
    let sampleCardItem = CardItem(timestamp: Date(), code: "123ABC", name: "Westway", barcodeType: BarcodeType.code128)
    EditCardItemView(cardItem: sampleCardItem, navigationManager: NavigationManager(), onSave: { updatedItem in
        print("Saved item: \(updatedItem)")
    })
}
