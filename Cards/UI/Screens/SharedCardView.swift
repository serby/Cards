import SwiftUI

/// The "Add Card?" sheet for a card someone shared (SHARE-3): the card's face
/// and places, and Add Card, or Open Card when the app already has it.
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
                .navigationTitle("Add Card?")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(state == .unreadable ? "Done" : "Cancel") { dismiss() }
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
                confirmButton("Add Card", identifier: "addSharedCardButton", action: actions.add)
            }
        case let .alreadyAdded(card, places):
            details(card, places: places) {
                Label("You already have this card.", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityIdentifier("sharedCardAlreadyAddedMessage")
                confirmButton("Open Card", identifier: "openSharedCardButton", action: actions.open)
            }
        case .unreadable:
            ContentUnavailableView("This link doesn't contain a card.", systemImage: "creditcard.trianglebadge.exclamationmark")
                .accessibilityIdentifier("sharedCardUnreadableMessage")
        }
    }

    /// The face and the places, with what you can do about them held at the bottom.
    private func details<Footer: View>(_ card: CardDetail, places: [CardLocation], @ViewBuilder footer: () -> Footer) -> some View {
        let footer = footer()
        return List {
            Section {
                CardFaceView(card: card)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if !places.isEmpty {
                Section("Locations") {
                    ForEach(places) { CardLocationRow($0) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) { footer }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.bar)
        }
    }

    private func confirmButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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
