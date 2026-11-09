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
            .environment(\.distanceUnits, entry.distanceUnits)
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
    /// The units chosen in the app's Settings (SET-4).
    var distanceUnits = DistanceUnits.automatic
}

struct CardTimelineProvider: AppIntentTimelineProvider {
    /// How long a "nearest card" stays up before WidgetKit is asked for another.
    /// WidgetKit spaces reloads out further when its daily budget runs low.
    static let refreshInterval: TimeInterval = 15 * 60

    private let snapshot: WidgetSnapshot
    private let settings: WidgetSettings
    private let location: WidgetLocation
    private let log: WidgetLog

    init(
        snapshot: WidgetSnapshot = .live,
        settings: WidgetSettings = .live,
        location: WidgetLocation = .live(log: .live),
        log: WidgetLog = .live
    ) {
        self.snapshot = snapshot
        self.settings = settings
        self.location = location
        self.log = log
    }

    func placeholder(in context: Context) -> CardEntry {
        CardEntry(
            date: .now,
            card: CardWidgetState(name: "Joe's Market", code: "5012345678900", barcodeType: .ean13, color: .blue),
            followsLocation: false
        )
    }

    func snapshot(for configuration: SelectCardIntent, in context: Context) async -> CardEntry {
        await entry(for: configuration, locate: !context.isPreview, reload: context.isPreview ? "gallery preview" : "snapshot")
    }

    func timeline(for configuration: SelectCardIntent, in context: Context) async -> Timeline<CardEntry> {
        let entry = await entry(for: configuration, locate: true, reload: "timeline")
        // A chosen card only changes when the app rewrites the snapshot, which
        // reloads the widget itself.
        let next = Date.now.addingTimeInterval(Self.refreshInterval)
        let policy: TimelineReloadPolicy = entry.followsLocation ? .after(next) : .never
        let when = entry.followsLocation ? "after \(next.formatted(date: .omitted, time: .shortened))" : "never, until the cards change"
        log.write("timeline: asks for the next reload \(when)")
        return Timeline(entries: [entry], policy: policy)
    }

    private func entry(for configuration: SelectCardIntent, locate: Bool, reload: String) async -> CardEntry {
        let cards = snapshot.read()
        let chosen = configuration.card?.code.flatMap { code in cards.first { $0.code == code } }
        let needsLocation = cards.contains { !$0.locations.isEmpty }
        let setting = chosen.map { "chosen card \"\($0.name)\"" }
            ?? (configuration.card?.code == nil ? "nearest card" : "chosen card missing, so nearest card")
        log.write("\(reload): start, \(setting), \(cards.count) cards, \(cards.filter { !$0.locations.isEmpty }.count) with places")
        let here = locate && needsLocation ? await location.current() : nil
        let card = chosen ?? cards.nearest(to: here)
        let state = card?.state(near: here)
        let why =
            if chosen != nil { "the chosen card" } else if here != nil { "the nearest card" } else { "the first card, as there is no location" }
        let distance = state?.proximity.map { ", \(Int($0.distance)) m from \($0.placeName)" } ?? ", no distance"
        log.write("\(reload): shows \(state.map { "\"\($0.name)\"" } ?? "no card"), \(why)\(distance)")
        return CardEntry(
            date: .now,
            card: state,
            followsLocation: chosen == nil && needsLocation,
            distanceUnits: settings.distanceUnits()
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
