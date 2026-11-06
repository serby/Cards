import CoreLocation
import SwiftUI

/// The add/edit form. The scanner is a view slot so the camera stays in
/// `CardsScanner` and stories can substitute a stand-in.
public struct CardEditView<Scanner: View>: View {
    @Binding var draft: CardDraft
    let actions: CardEditActions
    private let autofocusesName: Bool
    /// Where the location picker opens: the user's last known location, if any.
    private let mapCentre: CLLocationCoordinate2D?
    /// Codes other cards already use, which this card cannot take.
    let takenCodes: Set<String>
    /// The Settings switch for every card's arrival notifications.
    let arrivalNotificationsEnabled: Bool
    private let showsScanner: Bool
    private let scanner: () -> Scanner
    /// Choose Photo and Choose File under the scanner (CARD-13). Nil offers
    /// neither, as when editing a card.
    private let barcodeImport: BarcodeImportActions?

    @FocusState private var focusedField: Field?
    @State private var showsLocationPicker = false
    @State var showsIconPicker = false
    /// The icon the grid's scroll view is at: the card's icon as the sheet opens.
    @State var iconPickerPosition: String?
    @State var confirmsDelete = false
    /// Counts deletes, so the delete haptic plays (A11Y-5).
    @State var deletes = 0
    /// The place whose row was tapped, open in the picker to change it.
    @State private var editingLocation: CardLocation?
    /// The name takes focus once, not each time the form is seen again after switching tabs.
    @State private var hasAutofocused = false
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityAnnouncer) private var announcer

    private enum Field {
        case name, code
    }

    /// "Delete Joe's Market?", or "Delete this card?" while the name is blank.
    var deleteTitle: Text {
        let name = draft.trimmedName
        if name.isEmpty {
            return Text(
                "Delete this card?",
                comment: "Title of the dialog that asks before deleting a card from the card form, while the card has no name."
            )
        }
        return Text(
            "Delete \(name)?",
            comment: """
            Title of the dialog that asks before deleting a card from the card form. \
            The argument is the card's name, such as Joe's Market.
            """
        )
    }

    /// Labels and fields side by side, or stacked at accessibility text sizes,
    /// where a field beside its label would show only a few characters.
    private var stacksFields: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var rowLayout: AnyLayout {
        stacksFields
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout())
    }

    /// Text in a field beside its label keeps to the far edge; under it, to
    /// the label's edge.
    private var nameAlignment: TextAlignment {
        stacksFields ? .leading : .trailing
    }

    /// The code field is laid out left to right in every language, as codes are
    /// written, so in a right-to-left form its text keeps to the same edge as the
    /// name above it by aligning to the opposite of the name's alignment.
    private var codeAlignment: TextAlignment {
        guard layoutDirection == .rightToLeft else { return nameAlignment }
        return nameAlignment == .leading ? .trailing : .leading
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
                    // At least 250 pt, and taller when what the scanner shows
                    // needs it, such as the message when camera access is off.
                    scanner()
                        .frame(maxWidth: .infinity, minHeight: 250)
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
                rowLayout {
                    // The field carries this label, so VoiceOver reads it once and
                    // "Tap Name" in Voice Control reaches the field.
                    // No Spacer: the field fills the row itself, and a Spacer in an
                    // AnyLayout does not know its axis, so it made the row taller.
                    nameLabel
                        .accessibilityHidden(true)
                    // Both fields wrap rather than cut a long name or code off at
                    // large text sizes; Return moves on to the next field.
                    // The prompt wraps behind the field rather than being cut off.
                    TextField(
                        "Enter name",
                        text: $draft.name.singleLine { focusedField = .code },
                        prompt: Text(verbatim: ""),
                        axis: .vertical
                    )
                    .submitLabel(.next)
                    .multilineTextAlignment(nameAlignment)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .name)
                    .accessibilityIdentifier("nameTextField")
                    .accessibilityLabel(nameLabel)
                    .accessibilityHint(
                        Text("Sets the name shown for this card in your list", comment: "VoiceOver hint for the card name field in the card form.")
                    )
                    .wrappingPrompt(
                        Text("Enter name", comment: "Placeholder in the empty card name field, such as Joe's Market."),
                        isShown: draft.name.isEmpty,
                        alignment: nameAlignment,
                        onTap: { focusedField = .name }
                    )
                }

                rowLayout {
                    codeLabel
                        .accessibilityHidden(true)
                    TextField(
                        "Enter code",
                        text: $draft.code.singleLine { focusedField = nil },
                        prompt: Text(verbatim: ""),
                        axis: .vertical
                    )
                    .submitLabel(.done)
                    .multilineTextAlignment(codeAlignment)
                    .readsLeftToRight()
                    .keyboardType(.default)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .code)
                    .accessibilityIdentifier("codeTextField")
                    .accessibilityLabel(codeLabel)
                    .accessibilityHint(
                        Text(
                            "Sets the code for this card's barcode",
                            comment: "VoiceOver hint for the field for the number or text that the barcode encodes, in the card form."
                        )
                    )
                    // Outside readsLeftToRight(), so the prompt follows the
                    // language, keeping to the same edge as the name's.
                    .wrappingPrompt(
                        Text("Enter code", comment: "Placeholder in the empty field for the number or text that the barcode encodes."),
                        isShown: draft.code.isEmpty,
                        alignment: nameAlignment,
                        onTap: { focusedField = .code }
                    )
                }
            } footer: {
                if draft.codeIsTaken(by: takenCodes) {
                    Label(
                        LocalizedStringResource(
                            "Another card already uses this code.",
                            comment: "Message under the code field in the card form when the code typed is already another card's."
                        ),
                        systemImage: "exclamationmark.circle"
                    )
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityIdentifier("codeTakenMessage")
                }
            }

            Section {
                // Side by side, or the menu under its label at accessibility
                // sizes, as the fields above go under theirs: beside each other
                // the label and the format each had half the row and wrapped a
                // word or less to a line ("Bar- / code / Type", "EAN / -13").
                // The row draws the label in both layouts, so nothing is
                // swapped for something else as the text size changes.
                rowLayout {
                    barcodeTypeLabel
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                    barcodeTypePicker
                        .labelsHidden()
                }
            }

            Section {
                CardColorPicker(selection: $draft.color)
            } header: {
                // Headings, footers and prompts take the app's secondary text: the
                // system's grey is 3.2:1 on the form's background, and its
                // placeholder grey 1.9:1.
                Text("Colour", comment: "Section heading above the colour swatches in the card form. A noun.")
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityIdentifier("colourSectionHeader")
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
                    .accessibilityHint(
                        Text("Opens the map to change this place", comment: "VoiceOver hint for one of the card's places in the card form.")
                    )
                    .accessibilityIdentifier("locationRow_\(location.name)")
                    // A way to remove a place without swiping.
                    .contextMenu {
                        Button(role: .destructive) {
                            draft.locations.removeAll { $0.id == location.id }
                            announcer.announce(Announcements.deletedPlaces([location.name]))
                        } label: {
                            Label(
                                LocalizedStringResource(
                                    "Delete",
                                    comment: "Menu item that deletes a card in the list, or a place in the card form. A verb."
                                ),
                                systemImage: "trash"
                            )
                        }
                    }
                }
                .onDelete { offsets in
                    let names = offsets.map { draft.locations[$0].name }
                    draft.locations.remove(atOffsets: offsets)
                    announcer.announce(Announcements.deletedPlaces(names))
                }

                // Only a card with somewhere to arrive can notify you.
                if !draft.locations.isEmpty {
                    Toggle(isOn: $draft.notifiesOnArrival) {
                        Text(
                            "Notify When I Arrive",
                            comment: "Switch in the card form, under the card's places, that sends a notification when you arrive at one of them."
                        )
                    }
                    .tint(.accent)
                    .disabled(!arrivalNotificationsEnabled)
                }

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
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityIdentifier("locationsSectionHeader")
            } footer: {
                locationsFooter
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityIdentifier("locationsFooter")
            }

            if actions.delete != nil {
                Section {
                    deleteButton
                }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: deletes)
        .sheet(isPresented: $showsLocationPicker) {
            LocationPickerView(
                centre: mapCentre,
                search: actions.placeSearch,
                onAppear: actions.requestLocationAccess,
                onAdd: { location in
                    draft.locations.append(location)
                    announcer.announce(Announcements.added(location.name))
                }
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
        // On the form for the UI tests, which scroll it; the controls inside keep
        // their own identifiers.
        .accessibilityIdentifier("editCardForm")
        .task {
            // With VoiceOver on, jumping to the field would cut across it reading
            // the new screen; VoiceOver users reach the field themselves.
            guard autofocusesName, !hasAutofocused, !voiceOverEnabled else { return }
            hasAutofocused = true
            try? await Task.sleep(for: .seconds(0.6))
            focusedField = .name
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: actions.save) {
                    Text("Save", comment: "Toolbar button that saves the card form. A verb.")
                }
                .disabled(!draft.canSave(takenCodes: takenCodes))
                // Labelled by its visible text, so "Tap Save" works in Voice Control.
                .keyboardShortcut("s")
                .accessibilityIdentifier("saveCardButton")
                .accessibilityHint(saveHint)
            }
        }
    }
}

#if DEBUG
#Preview("Edit") {
    @Previewable @State var draft = CardDraft.sample
    NavigationStack {
        CardEditView(draft: $draft, actions: CardEditActions(delete: {}))
            .navigationTitle(Text(verbatim: "Edit Card"))
    }
    .environment(\.accessibilityAnnouncer, .silent)
}

#Preview("Add") {
    @Previewable @State var draft = CardDraft.empty
    NavigationStack {
        CardEditView(draft: $draft, barcodeImport: BarcodeImportActions()) { ScannerPlaceholderView() }
            .navigationTitle(Text(verbatim: "Add Card"))
    }
    .environment(\.accessibilityAnnouncer, .silent)
}
#endif
