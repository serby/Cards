import SwiftData
import SwiftUI
import UIKit

/// Development > Test Notification (DEV-2): sends any card's arrival
/// notification a few seconds after a tap, without going to the place. It goes
/// through the injected notification client, so tapping it opens the card
/// through the app's router, as a real one does.
struct TestNotificationScreen: View {
    @Query(sort: \CardItem.order) private var cards: [CardItem]
    @Environment(\.notificationClient) private var notifications
    @Environment(\.accessibilityAnnouncer) private var announcer
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var blocked = false
    @State private var status: String?

    var body: some View {
        List {
            if blocked {
                Section {
                    Button(action: openNotificationSettings) {
                        Label("Notifications are off for Card Barcodes. Turn them on in Settings.", systemImage: "bell.slash")
                            .font(.callout)
                    }
                    .foregroundColor(.accent)
                    .accessibilityIdentifier("openNotificationSettingsButton")
                }
            }

            if !cards.isEmpty {
                Section {
                    ForEach(cards) { card in
                        Button {
                            Task { await send(card) }
                        } label: {
                            row(for: card)
                        }
                        .accessibilityHint("Sends its arrival notification in \(seconds) seconds")
                        .accessibilityIdentifier("testNotificationCard-\(card.code)")
                    }
                } header: {
                    Text("Cards")
                        .foregroundColor(.secondaryText)
                } footer: {
                    Text(status ?? "Tap a card to get its arrival notification in \(seconds) seconds, even with the app open.")
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.primaryBackground)
        .overlay {
            if cards.isEmpty {
                ContentUnavailableView(
                    "No Cards",
                    systemImage: "bell.slash",
                    description: Text("Add a card to send its arrival notification.")
                )
            }
        }
        .navigationTitle("Test Notification")
        .navigationBarTitleDisplayMode(.inline)
        // Checked again on coming back, in case notifications were allowed in Settings.
        .task(id: scenePhase) {
            blocked = await notifications.authorizationStatus() == .denied
        }
    }

    private var seconds: Int {
        Int(TestArrival.delay)
    }

    private func row(for card: CardItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.name)
                .foregroundColor(.primaryText)
            Text("At \(TestArrival.place(for: plan(card)).name)")
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }

    private func plan(_ card: CardItem) -> ArrivalPlan.Card {
        ArrivalPlan.Card(name: card.name, code: card.code, barcodeType: card.getBarcodeType(), locations: card.locations)
    }

    /// Asks for permission if it never has been, then schedules the card's alert.
    private func send(_ card: CardItem) async {
        guard (try? await notifications.requestAuthorization()) == true else {
            blocked = true
            return
        }
        blocked = false
        do {
            try await notifications.addAfter(TestArrival.alert(for: plan(card)), TestArrival.delay)
            status = "The notification for \(card.name) arrives in \(seconds) seconds."
        } catch {
            status = "The notification for \(card.name) could not be sent: \(error.localizedDescription)"
        }
        if let status {
            announcer.announce(status)
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        openURL(url)
    }
}
