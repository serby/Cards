import CoreLocation
import SwiftUI
import WidgetKit

/// A medium Home Screen widget showing one card's barcode: the card nearest to
/// you, or one picked when editing the widget.
struct CardWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetSnapshot.widgetKind, intent: SelectCardIntent.self, provider: CardTimelineProvider()) { entry in
            CardWidgetView(card: entry.card) {
                if entry.followsLocation {
                    RefreshButton()
                }
            }
            .widgetURL(entry.card?.url)
            .containerBackground(for: .widget) {
                Rectangle().fill((entry.card?.color ?? .standard).widgetFill)
                    .keepsColoursWhenInverted()
            }
        }
        .configurationDisplayName(
            Text(
                "Card",
                comment: """
                    A noun: one loyalty card. The Home Screen widget's name in the widget gallery, the title of its setting for which card to \
                    show, and what Shortcuts calls a card.
                    """
            )
        )
        .description(
            Text(
                "Shows the barcode of the card nearest to you, or one you choose.",
                comment: "Description of the Home Screen widget in the widget gallery."
            )
        )
        .supportedFamilies([.systemMedium])
    }
}

struct CardEntry: TimelineEntry {
    let date: Date
    let card: CardWidgetState?
    /// Whether the card depends on where you are, so a refresh can change it.
    let followsLocation: Bool
}

struct CardTimelineProvider: AppIntentTimelineProvider {
    /// How long a "nearest card" stays up before WidgetKit is asked for another.
    /// WidgetKit spaces reloads out further when its daily budget runs low.
    static let refreshInterval: TimeInterval = 15 * 60

    private let snapshot: WidgetSnapshot
    private let location: WidgetLocation

    init(snapshot: WidgetSnapshot = .live, location: WidgetLocation = .live) {
        self.snapshot = snapshot
        self.location = location
    }

    func placeholder(in context: Context) -> CardEntry {
        CardEntry(
            date: .now,
            card: CardWidgetState(name: "Joe's Market", code: "5012345678900", barcodeType: .ean13, color: .blue),
            followsLocation: false
        )
    }

    func snapshot(for configuration: SelectCardIntent, in context: Context) async -> CardEntry {
        await entry(for: configuration, locate: !context.isPreview)
    }

    func timeline(for configuration: SelectCardIntent, in context: Context) async -> Timeline<CardEntry> {
        let entry = await entry(for: configuration, locate: true)
        // A chosen card only changes when the app rewrites the snapshot, which
        // reloads the widget itself.
        let policy: TimelineReloadPolicy = entry.followsLocation ? .after(.now.addingTimeInterval(Self.refreshInterval)) : .never
        return Timeline(entries: [entry], policy: policy)
    }

    private func entry(for configuration: SelectCardIntent, locate: Bool) async -> CardEntry {
        let cards = snapshot.read()
        let chosen = configuration.card?.code.flatMap { code in cards.first { $0.code == code } }
        let needsLocation = cards.contains { !$0.locations.isEmpty }
        let here = locate && needsLocation ? await location.current() : nil
        let card = chosen ?? cards.nearest(to: here)
        return CardEntry(
            date: .now,
            card: card?.state(near: here),
            followsLocation: chosen == nil && needsLocation
        )
    }
}

/// Finds the nearest card again, for when you have moved since the last refresh.
private struct RefreshButton: View {
    var body: some View {
        Button(intent: RefreshCardWidgetIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.caption.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(.thinMaterial, in: .circle)
                // Drawn at 28 pt, but 44 pt to tap, the least a finger needs.
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                "Find nearest card",
                comment: "VoiceOver label for the Home Screen widget's refresh button, which finds the card nearest to you again."
            )
        )
    }
}
