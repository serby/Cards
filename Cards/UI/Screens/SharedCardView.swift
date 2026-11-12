import SwiftUI

/// The "Add Card?" sheet for a card someone shared (SHARE-3): the card's face
/// with its notes, its places, and Add Card, or Open Card when the app already
/// has it.
public struct SharedCardView: View {
    private let state: SharedCardState
    private let actions: SharedCardActions

    @Environment(\.dismiss) private var dismiss

    public init(state: SharedCardState, actions: SharedCardActions = SharedCardActions()) {
        self.state = state
        self.actions = actions
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle(
                    Text("Add Card?", comment: "Title of the sheet that opens from a link to a card someone shared, asking whether to add it.")
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            if state == .unreadable {
                                Text("Done", comment: "Closes the sheet for a shared card when the link holds no card.")
                            } else {
                                Text("Cancel", comment: "Closes the sheet for a card someone shared without adding the card.")
                            }
                        }
                        .accessibilityIdentifier("cancelSharedCardButton")
                    }
                }
        }
        .accessibilityIdentifier("sharedCardSheet")
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case let .new(card, places):
            details(card, places: places) {
                confirmButton(
                    Text("Add Card", comment: "Button at the bottom of the sheet for a card someone shared, which adds the card to the list."),
                    identifier: "addSharedCardButton",
                    action: actions.add
                )
            }
        case let .alreadyAdded(card, places):
            details(card, places: places) {
                Label(
                    LocalizedStringResource(
                        "You already have this card.",
                        comment: "In the sheet for a card someone shared, above Open Card, when a card with the same code is already in the list."
                    ),
                    systemImage: "checkmark.circle"
                )
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityIdentifier("sharedCardAlreadyAddedMessage")
                confirmButton(
                    Text("Open Card", comment: "Button in the sheet for a card someone shared, when the card is already in the list: opens it."),
                    identifier: "openSharedCardButton",
                    action: actions.open
                )
            }
        case .unreadable:
            ContentUnavailableView(
                LocalizedStringResource(
                    "This link doesn't contain a card.",
                    comment: "In the sheet that opens from a link to a shared card, when the link is damaged or holds no card."
                ),
                systemImage: "creditcard.trianglebadge.exclamationmark"
            )
            .accessibilityIdentifier("sharedCardUnreadableMessage")
        }
    }

    /// The face with its notes, as the card's screen shows them, and the places,
    /// with what you can do about them held at the bottom.
    private func details<Footer: View>(_ card: CardDetail, places: [CardLocation], @ViewBuilder footer: () -> Footer) -> some View {
        let footer = footer()
        return List {
            Section {
                CardFaceView(card: card) {
                    if let notes = card.notes {
                        NotesPanel(notes: notes)
                    }
                }
                    .cardColumn()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if !places.isEmpty {
                Section {
                    ForEach(places) { CardLocationRow($0) }
                } header: {
                    Text("Locations", comment: "Section heading in the sheet for a card someone shared, over the places that come with the card.")
                }
            }
        }
        // The places and the buttons keep to the card's column, as on the card's screen (CARD-4).
        .cardColumnMargins()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) { footer }
                .cardColumn()
                .padding()
                .background(.bar)
        }
    }

    private func confirmButton(_ title: Text, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            title
                .font(.headline)
                // White on the light accent and black on the dark one, which both
                // meet WCAG AA; white on the dark accent would not.
                .foregroundStyle(Color.primaryBackground)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview("New card") {
    SharedCardView(state: .new(.sample, places: CardLocation.samples))
}

#Preview("New card with notes") {
    SharedCardView(state: .new(.withNotes, places: CardLocation.samples))
}

#Preview("Already here") {
    SharedCardView(state: .alreadyAdded(.sample, places: []))
}

#Preview("Unreadable link") {
    SharedCardView(state: .unreadable)
}
#endif
