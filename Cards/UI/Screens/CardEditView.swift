import CoreLocation
import SwiftUI

/// The add/edit form. The scanner is a view slot so the camera stays in
/// `CardsScanner` and stories can substitute a stand-in.
public struct CardEditView<Scanner: View>: View {
    @Binding private var draft: CardDraft
    private let actions: CardEditActions
    private let autofocusesName: Bool
    /// Where the location picker opens: the user's last known location, if any.
    private let mapCentre: CLLocationCoordinate2D?
    /// Codes other cards already use, which this card cannot take.
    private let takenCodes: Set<String>
    /// The Settings switch for every card's arrival notifications.
    private let arrivalNotificationsEnabled: Bool
    private let showsScanner: Bool
    private let scanner: () -> Scanner
    /// Choose Photo and Choose File under the scanner (CARD-13). Nil offers
    /// neither, as when editing a card.
    private let barcodeImport: BarcodeImportActions?

    @FocusState private var focusedField: Field?
    @State private var showsLocationPicker = false
    @State private var showsIconPicker = false
    /// The icon the grid's scroll view is at: the card's icon as the sheet opens.
    @State private var iconPickerPosition: String?
    @State private var confirmsDelete = false
    /// Counts deletes, so the delete haptic plays (A11Y-5).
    @State private var deletes = 0

    /// "Delete Joe's Market?", or "Delete this card?" while the name is blank.
    private var deleteTitle: String {
        "Delete \(draft.trimmedName.isEmpty ? "this card" : draft.trimmedName)?"
    }
    /// The place whose row was tapped, open in the picker to change it.
    @State private var editingLocation: CardLocation?
    /// The name takes focus once, not each time the form is seen again after switching tabs.
    @State private var hasAutofocused = false

    private enum Field {
        case name, code
    }

    public init(
        draft: Binding<CardDraft>,
        actions: CardEditActions = CardEditActions(),
        autofocusesName: Bool = false,
        mapCentre: CLLocationCoordinate2D? = nil,
        takenCodes: Set<String> = [],
        arrivalNotificationsEnabled: Bool = true,
        showsScanner: Bool = true,
        barcodeImport: BarcodeImportActions? = nil,
        @ViewBuilder scanner: @escaping () -> Scanner
    ) {
        _draft = draft
        self.actions = actions
        self.autofocusesName = autofocusesName
        self.mapCentre = mapCentre
        self.takenCodes = takenCodes
        self.arrivalNotificationsEnabled = arrivalNotificationsEnabled
        self.showsScanner = showsScanner
        self.barcodeImport = barcodeImport
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
            }

            if let barcodeImport {
                // Fills the code and type as the camera does.
                BarcodeImportSection(actions: barcodeImport) { found in
                    draft.code = found.code
                    draft.barcodeType = found.type
                }
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
            } footer: {
                if draft.codeIsTaken(by: takenCodes) {
                    Label("Another card already uses this code.", systemImage: "exclamationmark.circle")
                        .foregroundStyle(Color.secondaryText)
                        .accessibilityIdentifier("codeTakenMessage")
                }
            }

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

            Section("Colour") {
                CardColorPicker(selection: $draft.color)
            }

            Section {
                iconRow
            }

            Section {
                ForEach(draft.locations) { location in
                    Button {
                        editingLocation = location
                    } label: {
                        CardLocationRow(location)
                            .foregroundStyle(Color.primaryText)
                    }
                    .accessibilityHint("Opens the map to change this place")
                    .accessibilityIdentifier("locationRow_\(location.name)")
                }
                .onDelete { draft.locations.remove(atOffsets: $0) }

                // Only a card with somewhere to arrive can notify you.
                if !draft.locations.isEmpty {
                    Toggle("Notify When I Arrive", isOn: $draft.notifiesOnArrival)
                        .tint(.accent)
                        .disabled(!arrivalNotificationsEnabled)
                }

                Button {
                    showsLocationPicker = true
                } label: {
                    Label("Add Location", systemImage: "mappin.and.ellipse")
                }
                .accessibilityIdentifier("addLocationRowButton")
            } header: {
                Text("Locations")
            } footer: {
                Text(locationsFooter)
            }

            if actions.delete != nil {
                Section {
                    Button("Delete Card", role: .destructive) {
                        confirmsDelete = true
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("deleteCardButton")
                    .accessibilityHint("Asks before deleting this card from all your devices")
                }
            }
        }
        .confirmationDialog(deleteTitle, isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete Card", role: .destructive) {
                deletes += 1
                actions.delete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It is deleted from all your devices. This cannot be undone.")
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: deletes)
        .sheet(isPresented: $showsLocationPicker) {
            LocationPickerView(
                centre: mapCentre,
                search: actions.placeSearch,
                onAppear: actions.requestLocationAccess,
                onAdd: { draft.locations.append($0) }
            )
        }
        .sheet(item: $editingLocation) { location in
            LocationPickerView(
                editing: location,
                search: actions.placeSearch,
                onAppear: actions.requestLocationAccess,
                onSave: { draft.update($0) }
            )
        }
        .sheet(isPresented: $showsIconPicker) {
            iconPicker
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("editCardForm")
        .task {
            guard autofocusesName, !hasAutofocused else { return }
            hasAutofocused = true
            try? await Task.sleep(for: .seconds(0.6))
            focusedField = .name
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: actions.save)
                    .disabled(!draft.canSave(takenCodes: takenCodes))
                    .accessibilityIdentifier("saveCardButton")
                    .accessibilityLabel("Save card")
                    .accessibilityHint(
                        draft.canSave(takenCodes: takenCodes) ? "Save changes to this card" : "Needs a name and a code no other card uses"
                    )
            }
        }
    }
}

extension CardEditView {
    /// Shows the card's icon, or None, and opens the grid to choose one.
    private var iconRow: some View {
        Button {
            iconPickerPosition = nil
            showsIconPicker = true
        } label: {
            HStack {
                Text("Icon")
                    .foregroundStyle(Color.primaryText)
                Spacer()
                if let icon = draft.icon {
                    Image(systemName: icon)
                        .foregroundStyle(Color.secondaryText)
                        .accessibilityHidden(true)
                } else {
                    Text("None")
                        .foregroundStyle(Color.secondaryText)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.tertiaryText)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Icon")
        .accessibilityValue(CardIcon.label(for: draft.icon) ?? "None")
        .accessibilityHint("Opens a grid of icons to choose from")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("iconRow")
    }

    /// The icon grid in a sheet, open at the card's icon. Choosing one closes it.
    private var iconPicker: some View {
        NavigationStack {
            ScrollView {
                CardIconPicker(selection: $draft.icon, color: draft.color) {
                    showsIconPicker = false
                }
                .padding()
            }
            // The card's icon can be far down the grid, below the sheet's first height.
            // Set once the grid is there: a position given before the sheet opens is lost.
            .scrollPosition(id: $iconPickerPosition, anchor: .center)
            .onAppear { iconPickerPosition = draft.icon }
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsIconPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var locationsFooter: String {
        if draft.locations.isEmpty {
            "Add a place to be reminded when you arrive there."
        } else if !arrivalNotificationsEnabled {
            "Arrival notifications are off for every card in Settings."
        } else if draft.notifiesOnArrival {
            "When you arrive at one of these places, a notification reminds you. Tap it to open the card."
        } else {
            "This card won't remind you when you arrive."
        }
    }
}

public extension CardEditView where Scanner == EmptyView {
    /// Form only — no scanner section.
    init(
        draft: Binding<CardDraft>,
        actions: CardEditActions = CardEditActions(),
        autofocusesName: Bool = false,
        mapCentre: CLLocationCoordinate2D? = nil,
        takenCodes: Set<String> = [],
        arrivalNotificationsEnabled: Bool = true
    ) {
        self.init(
            draft: draft,
            actions: actions,
            autofocusesName: autofocusesName,
            mapCentre: mapCentre,
            takenCodes: takenCodes,
            arrivalNotificationsEnabled: arrivalNotificationsEnabled,
            showsScanner: false,
            scanner: { EmptyView() }
        )
    }
}

#if DEBUG
#Preview("Edit") {
    @Previewable @State var draft = CardDraft.sample
    NavigationStack {
        CardEditView(draft: $draft, actions: CardEditActions(delete: {}))
            .navigationTitle("Edit Card")
    }
}

#Preview("Add") {
    @Previewable @State var draft = CardDraft.empty
    NavigationStack {
        CardEditView(draft: $draft, barcodeImport: BarcodeImportActions()) { ScannerPlaceholderView() }
            .navigationTitle("Add Card")
    }
    .environment(\.accessibilityAnnouncer, .silent)
}
#endif
