import CardsCore
import CardsScanner
import SwiftUI

public struct EditCardItemView: View {
    private var cardItem: CardItem
    @State private var tempName: String
    @State private var tempCode: String
    @State private var selectedType: String
    @State private var scannedCode: String?
    @State private var scannedBarcodeType: BarcodeType?
    @FocusState private var focusedField: Field?

    enum Field {
        case name, code
    }

    let navigationManager: NavigationManager?
    var onSave: ((CardItem) -> Void)?
    private var isNewCard: Bool { onSave != nil }

    public init(cardItem: CardItem, navigationManager: NavigationManager? = nil, onSave: ((CardItem) -> Void)? = nil) {
        self.cardItem = cardItem
        self.navigationManager = navigationManager
        _tempName = State(initialValue: cardItem.name)
        _tempCode = State(initialValue: cardItem.code)
        _selectedType = State(initialValue: cardItem.type)
        self.onSave = onSave
    }

    public var body: some View {
        Form {
            if isNewCard {
                Section {
                    ScannerOverlayView(scannedCode: $scannedCode, barcodeType: $scannedBarcodeType)
                        .frame(height: 250)
                        .listRowInsets(EdgeInsets())
                }
                .accessibilityIdentifier("scannerSection")
            }

            Section {
                HStack {
                    Text("Name")
                        .accessibilityIdentifier("nameLabel")
                    Spacer()
                    TextField("Enter name", text: $tempName)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .name)
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
                        .focused($focusedField, equals: .code)
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
        .onChange(of: scannedCode) { _, newCode in
            if let code = newCode {
                tempCode = code
            }
        }
        .onChange(of: scannedBarcodeType) { _, newType in
            if let type = newType {
                selectedType = type.rawValue
            }
        }
        .task {
            guard !isNewCard else { return }
            try? await Task.sleep(for: .seconds(0.6))
            focusedField = .name
        }
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
