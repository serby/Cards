import SwiftUI

/// The add/edit form. The scanner is a view slot so the camera stays in
/// `CardsScanner` and stories can substitute a stand-in.
public struct CardEditView<Scanner: View>: View {
    @Binding private var draft: CardDraft
    private let actions: CardEditActions
    private let autofocusesName: Bool
    private let showsScanner: Bool
    private let scanner: () -> Scanner

    @FocusState private var focusedField: Field?
    @State private var showsLocationPicker = false

    private enum Field {
        case name, code
    }

    public init(
        draft: Binding<CardDraft>,
        actions: CardEditActions = CardEditActions(),
        autofocusesName: Bool = false,
        showsScanner: Bool = true,
        @ViewBuilder scanner: @escaping () -> Scanner
    ) {
        _draft = draft
        self.actions = actions
        self.autofocusesName = autofocusesName
        self.showsScanner = showsScanner
        self.scanner = scanner
    }

    public var body: some View {
        Form {
            if showsScanner {
                Section {
                    scanner()
                        .frame(height: 250)
                        .listRowInsets(EdgeInsets())
                }
                .accessibilityIdentifier("scannerSection")
            }

            Section {
                HStack {
                    Text("Name", comment: "Label beside the card's name field in the card form. A noun.")
                        .accessibilityIdentifier("nameLabel")
                    Spacer()
                    TextField(
                        "Enter name",
                        text: $draft.name,
                        prompt: Text("Enter name", comment: "Placeholder in the empty card name field, such as Tesco Clubcard.")
                    )
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .name)
                    .accessibilityIdentifier("cardDetailsSection.nameTextField")
                    .accessibilityLabel(Text("Card name", comment: "VoiceOver label for the card name field in the card form."))
                    .accessibilityHint(Text("Enter the name of this card", comment: "VoiceOver hint for the card name field in the card form."))
                }

                HStack {
                    Text("Code", comment: "Label beside the field for the number or text that the barcode encodes. A noun.")
                        .accessibilityIdentifier("codeLabel")
                    Spacer()
                    TextField(
                        "Enter code",
                        text: $draft.code,
                        prompt: Text("Enter code", comment: "Placeholder in the empty field for the number or text that the barcode encodes.")
                    )
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.default)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .code)
                    .accessibilityIdentifier("cardDetailsSection.codeTextField")
                    .accessibilityLabel(Text("Card code", comment: "VoiceOver label for the card's code field in the card form."))
                    .accessibilityHint(
                        Text("Enter the barcode number for this card", comment: "VoiceOver hint for the card's code field in the card form.")
                    )
                }
            }
            .accessibilityIdentifier("cardDetailsSection")

            Section {
                Picker(selection: $draft.barcodeType) {
                    ForEach(BarcodeType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                            .accessibilityIdentifier("barcodeType_\(type.rawValue.replacingOccurrences(of: " ", with: "_"))")
                    }
                } label: {
                    Text("Barcode Type", comment: "Label of the menu for choosing the card's barcode format, such as EAN-13 or QR Code.")
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("barcodeTypePicker")
                .accessibilityLabel(Text("Barcode type", comment: "VoiceOver label for the barcode format menu in the card form."))
                .accessibilityHint(
                    Text("Select the type of barcode for this card", comment: "VoiceOver hint for the barcode format menu in the card form.")
                )
            }
            .accessibilityIdentifier("barcodeTypeSection")

            Section {
                CardColorPicker(selection: $draft.color)
            } header: {
                Text("Colour", comment: "Section heading above the colour swatches in the card form. A noun.")
            }
            .accessibilityIdentifier("cardColorSection")

            Section {
                ForEach(draft.locations) { location in
                    CardLocationRow(location)
                }
                .onDelete { draft.locations.remove(atOffsets: $0) }

                Button {
                    showsLocationPicker = true
                } label: {
                    Label(
                        LocalizedStringResource(
                            "Add Location",
                            comment: "Button in the card form that opens a map for adding a place where the card is used."
                        ),
                        systemImage: "mappin.and.ellipse"
                    )
                }
                .accessibilityIdentifier("addLocationRowButton")
            } header: {
                Text("Locations", comment: "Section heading in the card form for the places where the card is used.")
            } footer: {
                Text(
                    "When you arrive at one of these places, the barcode appears on your Lock Screen.",
                    comment: "Footer under the card's places in the card form, explaining the arrival notification."
                )
            }
            .accessibilityIdentifier("cardLocationsSection")
        }
        .sheet(isPresented: $showsLocationPicker) {
            LocationPickerView(
                findPlace: actions.findPlace,
                onAppear: actions.requestLocationAccess,
                onAdd: { draft.locations.append($0) }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("editCardForm")
        .task {
            guard autofocusesName else { return }
            try? await Task.sleep(for: .seconds(0.6))
            focusedField = .name
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: actions.save) {
                    Text("Save", comment: "Toolbar button that saves the card form. A verb.")
                }
                .accessibilityIdentifier("saveCardButton")
                .accessibilityLabel(Text("Save card", comment: "VoiceOver label for the Save button in the card form."))
                .accessibilityHint(Text("Save changes to this card", comment: "VoiceOver hint for the Save button in the card form."))
            }
        }
    }
}

public extension CardEditView where Scanner == EmptyView {
    /// Form only — no scanner section.
    init(
        draft: Binding<CardDraft>,
        actions: CardEditActions = CardEditActions(),
        autofocusesName: Bool = false
    ) {
        self.init(
            draft: draft,
            actions: actions,
            autofocusesName: autofocusesName,
            showsScanner: false,
            scanner: { EmptyView() }
        )
    }
}
