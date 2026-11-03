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
                    Text("Name")
                        .accessibilityIdentifier("nameLabel")
                    Spacer()
                    TextField("Enter name", text: $draft.name)
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
                    TextField("Enter code", text: $draft.code)
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
                Picker("Barcode Type", selection: $draft.barcodeType) {
                    ForEach(BarcodeType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                            .accessibilityIdentifier("barcodeType_\(type.rawValue.replacingOccurrences(of: " ", with: "_"))")
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("barcodeTypePicker")
                .accessibilityLabel("Barcode type")
                .accessibilityHint("Select the type of barcode for this card")
            }
            .accessibilityIdentifier("barcodeTypeSection")

            Section("Colour") {
                CardColorPicker(selection: $draft.color)
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
                    Label("Add Location", systemImage: "mappin.and.ellipse")
                }
                .accessibilityIdentifier("addLocationRowButton")
            } header: {
                Text("Locations")
            } footer: {
                Text("When you arrive at one of these places, the barcode appears on your Lock Screen.")
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
                Button("Save", action: actions.save)
                    .accessibilityIdentifier("saveCardButton")
                    .accessibilityLabel("Save card")
                    .accessibilityHint("Save changes to this card")
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

/// Stand-in for the camera preview, for stories and previews.
public struct ScannerPlaceholderView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Rectangle().fill(.black)
            Text("Camera preview")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            Rectangle()
                .fill(Color.red.opacity(0.8))
                .frame(height: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("scannerView")
        .accessibilityLabel("Barcode scanner")
    }
}

#Preview("Edit") {
    @Previewable @State var draft = CardDraft.sample
    NavigationStack {
        CardEditView(draft: $draft)
            .navigationTitle("Edit Card")
    }
}

#Preview("Add") {
    @Previewable @State var draft = CardDraft.empty
    NavigationStack {
        CardEditView(draft: $draft) { ScannerPlaceholderView() }
            .navigationTitle("Add Card")
    }
}
