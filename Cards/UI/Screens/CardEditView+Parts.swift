import CoreLocation
import SwiftUI

// The form's rows and sheets, beside CardEditView.swift so each file stays
// readable. Internal rather than private only so the two files share them.

extension CardEditView {
    /// The format menu. Its label is hidden, as the row draws it, but
    /// VoiceOver still reads it.
    var barcodeTypePicker: some View {
        Picker(selection: $draft.barcodeType) {
            ForEach(BarcodeType.allCases, id: \.self) { type in
                Text(type.displayName).tag(type)
                    .accessibilityIdentifier("barcodeType_\(type.rawValue.replacingOccurrences(of: " ", with: "_"))")
            }
        } label: {
            barcodeTypeLabel
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("barcodeTypePicker")
        .accessibilityHint(
            Text("Sets the type of barcode for this card", comment: "VoiceOver hint for the barcode format menu in the card form.")
        )
    }

    var barcodeTypeLabel: Text {
        Text("Barcode Type", comment: "Label of the menu for choosing the card's barcode format, such as EAN-13 or QR Code.")
    }

    var nameLabel: Text {
        Text("Name", comment: "Label beside the card's name field in the card form. A noun.")
    }

    var codeLabel: Text {
        Text("Code", comment: "Label beside the field for the number or text that the barcode encodes. A noun.")
    }

    /// Shows the card's icon, or None, and opens the grid to choose one.
    var iconRow: some View {
        Button {
            iconPickerScrolledByHand = false
            showsIconPicker = true
        } label: {
            // Side by side, or the value under its title at the accessibility
            // sizes, where beside it each word broke part-way ("Sym-bol", "Ohn-e").
            rowLayout {
                iconLabel
                    .foregroundStyle(Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    if let icon = draft.icon {
                        Image(systemName: icon)
                            .foregroundStyle(Color.secondaryText)
                            .accessibilityHidden(true)
                    } else {
                        noIcon
                            .foregroundStyle(Color.secondaryText)
                    }
                    // Forward, so it points left in a right-to-left language, as the
                    // system's own disclosure chevrons do.
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(iconLabel)
        .accessibilityValue(iconValue)
        .accessibilityHint(
            Text("Opens a grid of icons to choose from", comment: "VoiceOver hint for the Icon row in the card form.")
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("iconRow")
    }

    /// The icon grid in a sheet, open at the card's icon. Choosing one closes it.
    var iconPicker: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    CardIconPicker(selection: $draft.icon, color: draft.color) {
                        showsIconPicker = false
                    }
                    .padding()
                }
                .onScrollPhaseChange { _, phase in
                    if phase == .interacting { iconPickerScrolledByHand = true }
                }
                // The card's icon can be far down the grid, below the sheet's
                // first height. Scrolled to once the sheet has settled: iOS 26 and
                // 27 put a sheet's scroll view back at the top as it finishes
                // opening, losing a position given before. Not if the grid has
                // been scrolled by hand by then.
                .task {
                    try? await Task.sleep(for: .seconds(0.6))
                    if !iconPickerScrolledByHand, let icon = draft.icon {
                        proxy.scrollTo(icon, anchor: .center)
                    }
                }
            }
            .navigationTitle(iconLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showsIconPicker = false
                    } label: {
                        Text("Done", comment: "Button that closes the grid of icons opened from the card form.")
                    }
                    // Escape closes the grid too: nothing is chosen until a tap.
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    var iconLabel: Text {
        Text(
            "Icon",
            comment: """
            Label of the row in the card form that shows the card's icon and opens a grid to choose one, \
            and the title of that grid. A noun.
            """
        )
    }

    var noIcon: Text {
        Text("None", comment: "Shown in the card form's Icon row, and read by VoiceOver, when the card has no icon.")
    }

    /// The icon's name as VoiceOver reads the row's value, or None.
    var iconValue: Text {
        if let label = CardIcon.label(for: draft.icon) {
            Text(label)
        } else {
            noIcon
        }
    }

    /// Anything the card holder wants to keep with the card, below its places
    /// (CARD-14). The field grows with its text, and Return starts a new line.
    var notesSection: some View {
        Section {
            TextField("Add a note", text: $draft.notes, prompt: Text(verbatim: ""), axis: .vertical)
                .lineLimit(3...)
                .focused($focusedField, equals: .notes)
                .accessibilityIdentifier("notesTextField")
                .accessibilityLabel(notesLabel)
                .accessibilityHint(
                    Text("Sets notes shown on this card's screen", comment: "VoiceOver hint for the notes field in the card form.")
                )
                // The prompt wraps behind the field rather than being cut off.
                .wrappingPrompt(
                    Text("Add a note", comment: "Placeholder in the empty notes field in the card form, where any text can be kept with the card."),
                    isShown: draft.notes.isEmpty,
                    onTap: { focusedField = .notes }
                )
        } header: {
            notesLabel
                .foregroundStyle(Color.secondaryText)
                .accessibilityIdentifier("notesSectionHeader")
        } footer: {
            Text(
                "Notes show on the card's screen. They are left out when you share the card.",
                comment: "Footer under the notes field in the card form. Sharing sends the card as a link or a picture."
            )
            .foregroundStyle(Color.secondaryText)
            .accessibilityIdentifier("notesFooter")
        }
    }

    var notesLabel: Text {
        Text("Notes", comment: "Heading of a card's notes, on the card's screen and in the card form. A noun.")
    }

    /// Asks before deleting. The dialog hangs off the button, so on iPad its
    /// popover points at it rather than at the top of the form.
    var deleteButton: some View {
        Button(role: .destructive) {
            confirmsDelete = true
        } label: {
            Text("Delete Card", comment: "Button at the foot of the card form that asks before deleting the card. A verb.")
                .foregroundStyle(Color.destructive)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("deleteCardButton")
        .accessibilityHint(
            Text(
                "Asks before deleting this card from all your devices",
                comment: "VoiceOver hint for the Delete Card button in the card form."
            )
        )
        .confirmationDialog(deleteTitle, isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button(role: .destructive) {
                deletes += 1
                actions.delete?()
            } label: {
                Text("Delete Card", comment: "Destructive button in the card form's delete dialog that deletes the card. A verb.")
            }
            .accessibilityIdentifier("confirmDeleteCardButton")
            Button(role: .cancel) {} label: {
                Text("Cancel", comment: "Button in the delete-card dialog that keeps the card.")
            }
        } message: {
            Text(
                "It is deleted from all your devices. This cannot be undone.",
                comment: "Message in the dialog that asks before deleting a card from the card form."
            )
        }
    }

    var saveHint: Text {
        if draft.canSave(takenCodes: takenCodes) {
            Text("Saves the card", comment: "VoiceOver hint for the Save button in the card form, for a new card or a changed one.")
        } else {
            Text(
                "Needs a name and a code no other card uses",
                comment: """
                VoiceOver hint for the dimmed Save button in the card form, \
                while the card has no name or no code, or another card has its code.
                """
            )
        }
    }

    var locationsFooter: Text {
        if draft.locations.isEmpty {
            Text(
                "Add a place to be reminded when you arrive there.",
                comment: "Footer under the Locations section of the card form while the card has no places."
            )
        } else if !arrivalNotificationsEnabled {
            Text(
                "Arrival notifications are off for every card in Settings.",
                comment: "Footer under the card's places in the card form while the arrival notifications switch in Settings is off."
            )
        } else if draft.notifiesOnArrival {
            Text(
                "When you arrive at one of these places, a notification reminds you. Tap it to open the card.",
                comment: "Footer under the card's places in the card form while Notify When I Arrive is on. “It” is the notification."
            )
        } else {
            Text(
                "This card won't remind you when you arrive.",
                comment: "Footer under the card's places in the card form while Notify When I Arrive is off."
            )
        }
    }
}

public extension CardEditView where Scanner == EmptyView {
    /// Form only — no scanner section.
    init(
        draft: Binding<CardDraft>,
        actions: CardEditActions = CardEditActions(),
        mapCentre: CLLocationCoordinate2D? = nil,
        takenCodes: Set<String> = [],
        arrivalNotificationsEnabled: Bool = true
    ) {
        self.init(
            draft: draft,
            actions: actions,
            mapCentre: mapCentre,
            takenCodes: takenCodes,
            arrivalNotificationsEnabled: arrivalNotificationsEnabled,
            showsScanner: false,
            scanner: { EmptyView() }
        )
    }
}
