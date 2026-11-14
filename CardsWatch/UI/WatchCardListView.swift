import SwiftUI

/// The watch's list of cards (WATCH-2), in the iPhone list's own order, each
/// row on the card's colour with its icon, its name and how far away its
/// nearest place is. A row opens the card's screen by its code, which the
/// connector's navigation path holds. With no cards yet, it says where they
/// come from.
struct WatchCardListView: View {
    static let rowCornerRadius: CGFloat = 14

    let cards: [WatchCardSummary]
    /// The card whose place is closest, shown with its barcode above the list,
    /// as the phone shows the card for where you are (WATCH-6); nil when the
    /// watch doesn't know where it is, or no card has a place.
    var closest: WatchClosestCard?
    @Environment(\.distanceFormat) private var distanceFormat

    var body: some View {
        Group {
            if cards.isEmpty {
                emptyState
            } else {
                List {
                    if let closest {
                        Section {
                            NavigationLink(value: closest.summary.id) {
                                ClosestCard(card: closest)
                            }
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: Self.rowCornerRadius, style: .continuous).fill(closest.summary.color.rowFill)
                            )
                            .accessibilityLabel(spokenLabel(closest.summary))
                            .accessibilityIdentifier("watchClosestCard")
                        }
                    }
                    Section {
                        rows
                    }
                }
            }
        }
        .navigationTitle(Text("Cards", comment: "Title of the list of the user's loyalty cards on Apple Watch."))
    }

    private var rows: some View {
        ForEach(cards) { card in
                    NavigationLink(value: card.id) {
                        Row(card: card)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: Self.rowCornerRadius, style: .continuous).fill(card.color.rowFill))
                    // The name first, then the distance: "Joe's Market, You're at Joe's Market Notting Hill".
                    .accessibilityLabel(spokenLabel(card))
                    // By the card's code, so UI tests find it in any language.
                    .accessibilityIdentifier("watchCardRow_\(card.id)")
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "iphone")
                    .font(.title2)
                    .foregroundStyle(Color.accent)
                    .accessibilityHidden(true)
                Text("No Cards Yet", comment: "Title on Apple Watch before any cards have arrived from the iPhone.")
                    .font(.headline)
                Text(
                    "Open Card Barcodes on your iPhone, and your cards show here.",
                    comment: "On Apple Watch under “No Cards Yet”: the cards come from the iPhone app. Card Barcodes is the app's name."
                )
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("watchNoCards")
    }

    /// The name, or the name and then the distance as VoiceOver reads it.
    private func spokenLabel(_ card: WatchCardSummary) -> Text {
        guard let proximity = card.proximity else { return Text(card.name) }
        return Text(
            "\(card.name), \(proximity.spokenDescription(in: distanceFormat))",
            comment: """
                VoiceOver label for a card in the list on Apple Watch: the card's name, then how far away its nearest place is, \
                as in “Joe's Market, 350 metres from Joe's Market Notting Hill”.
                """
        )
    }

    /// The closest card: its name and distance over its barcode, ready to scan.
    private struct ClosestCard: View {
        let card: WatchClosestCard

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Row(card: card.summary)
                WatchBarcodeView(modules: card.modules, type: card.barcodeType)
                    .padding(.bottom, 6)
            }
        }
    }

    /// A card's row: its icon beside its name, with the distance under the name.
    private struct Row: View {
        let card: WatchCardSummary

        var body: some View {
            HStack(spacing: 8) {
                if let icon = card.icon {
                    // The name already says what the card is (CARD-12).
                    Image(systemName: icon)
                        .font(.title3)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name)
                        .font(.headline)
                    if let proximity = card.proximity {
                        ProximityLabel(proximity, highlightsHere: false, wraps: true)
                            .font(.footnote)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(card.color.ink)
            .padding(.vertical, 6)
        }
    }
}

#if DEBUG
#Preview("Cards") {
    NavigationStack {
        WatchCardListView(cards: WatchCardSummary.samples)
    }
}

#Preview("Miles") {
    NavigationStack {
        WatchCardListView(cards: WatchCardSummary.samples)
    }
    .environment(\.distanceUnits, .miles)
}

#Preview("No cards yet") {
    NavigationStack {
        WatchCardListView(cards: [])
    }
}
#endif
