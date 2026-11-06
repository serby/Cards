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
            iconPickerPosition = nil
            showsIconPicker = true
        } label: {
            HStack {
                iconLabel
                    .foregroundStyle(Color.primaryText)
                Spacer()
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
