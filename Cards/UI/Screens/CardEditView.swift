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
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityAnnouncer) private var announcer

    private enum Field {
        case name, code
    }

    /// The code field is laid out left to right in every language, as codes are
    /// written, so in a right-to-left form its text keeps to the same edge as the
    /// name above it by aligning to its own leading (left) edge.
    private var codeAlignment: TextAlignment {
        layoutDirection == .rightToLeft ? .leading : .trailing
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
            }

            Section {
                HStack {
                    // The field carries this label, so VoiceOver reads it once and
                    // "Tap Name" in Voice Control reaches the field.
                    nameLabel
                        .accessibilityHidden(true)
                    Spacer()
                    TextField(
                        "Enter name",
                        text: $draft.name,
                        prompt: Text("Enter name", comment: "Placeholder in the empty card name field, such as Tesco Clubcard.")
                    )
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .name)
                    .accessibilityIdentifier("nameTextField")
                    .accessibilityLabel(nameLabel)
                    .accessibilityHint(Text("Enter the name of this card", comment: "VoiceOver hint for the card name field in the card form."))
                }

                HStack {
                    codeLabel
                        .accessibilityHidden(true)
                    Spacer()
                    TextField(
                        "Enter code",
                        text: $draft.code,
                        prompt: Text("Enter code", comment: "Placeholder in the empty field for the number or text that the barcode encodes.")
                    )
                    .multilineTextAlignment(codeAlignment)
                    .readsLeftToRight()
                    .keyboardType(.default)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .code)
                    .accessibilityIdentifier("codeTextField")
                    .accessibilityLabel(codeLabel)
                    .accessibilityHint(
                        Text("Enter the barcode number for this card", comment: "VoiceOver hint for the card's code field in the card form.")
                    )
                }
            }

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
                .accessibilityHint(
                    Text("Select the type of barcode for this card", comment: "VoiceOver hint for the barcode format menu in the card form.")
                )
            }

            Section {
                CardColorPicker(selection: $draft.color)
            } header: {
                Text("Colour", comment: "Section heading above the colour swatches in the card form. A noun.")
            }

            Section {
                ForEach(draft.locations) { location in
                    CardLocationRow(location)
                        // A way to remove a place without swiping.
                        .contextMenu {
                            Button(role: .destructive) {
                                draft.locations.removeAll { $0.id == location.id }
                                announcer.announce(Announcements.deleted([location.name]))
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
                    announcer.announce(Announcements.deleted(names))
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
            } footer: {
                Text(
                    "When you arrive at one of these places, the barcode appears on your Lock Screen.",
                    comment: "Footer under the card's places in the card form, explaining the arrival notification."
                )
            }
        }
        .sheet(isPresented: $showsLocationPicker) {
            LocationPickerView(
                findPlace: actions.findPlace,
                onAppear: actions.requestLocationAccess,
                onAdd: { location in
                    draft.locations.append(location)
                    announcer.announce(Announcements.added(location.name))
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // With VoiceOver on, jumping to the field would cut across it reading
            // the new screen; VoiceOver users reach the field themselves.
            guard autofocusesName, !voiceOverEnabled else { return }
            try? await Task.sleep(for: .seconds(0.6))
            focusedField = .name
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: actions.save) {
                    Text("Save", comment: "Toolbar button that saves the card form. A verb.")
                }
                // Labelled by its visible text, so "Tap Save" works in Voice Control.
                .accessibilityIdentifier("saveCardButton")
                .accessibilityHint(
                    Text("Saves the card", comment: "VoiceOver hint for the Save button in the card form, for a new card or a changed one.")
                )
            }
        }
    }
}

private extension CardEditView {
    var nameLabel: Text {
        Text("Name", comment: "Label beside the card's name field in the card form. A noun.")
    }

    var codeLabel: Text {
        Text("Code", comment: "Label beside the field for the number or text that the barcode encodes. A noun.")
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
