import Foundation
import OSLog
import SwiftUI
import WidgetKit

/// The cards as the Home Screen widget sees them: a JSON file in the App Group
/// container that the app rewrites whenever its cards change. Injected, so only
/// the live value reaches the App Group and WidgetKit.
public struct WidgetSnapshot: Sendable {
    /// The cards last written, in list order. Empty when there is no snapshot yet
    /// or it cannot be read, which the widget shows as "no cards".
    public var read: @Sendable () -> [WidgetCard]
    /// Writes the cards and, if that changed the file, asks WidgetKit to redraw
    /// the widget. A failure is logged.
    public var write: @Sendable ([WidgetCard]) -> Void

    public init(read: @escaping @Sendable () -> [WidgetCard], write: @escaping @Sendable ([WidgetCard]) -> Void) {
        self.read = read
        self.write = write
    }
}

public extension WidgetSnapshot {
    static let appGroup = "group.net.serby.Cards"
    static let widgetKind = "CardWidget"

    /// The file in the App Group container, shared by the app and the widget.
    static let live = file(
        at: FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "widget-cards.json"),
        onChange: { WidgetCenter.shared.reloadTimelines(ofKind: widgetKind) }
    )

    /// A snapshot kept in the JSON file at `url`, calling `onChange` after a write
    /// that changed the file. With no `url` (the App Group is missing from the
    /// entitlements) it reads no cards and writes nothing.
    static func file(at url: URL?, onChange: @escaping @Sendable () -> Void = {}) -> Self {
        Self(
            read: {
                guard let url, let data = try? Data(contentsOf: url) else { return [] }
                return (try? JSONDecoder().decode([WidgetCard].self, from: data)) ?? []
            },
            write: { cards in
                guard let url else { return }
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .sortedKeys
                    let data = try encoder.encode(cards)
                    guard data != (try? Data(contentsOf: url)) else { return }
                    try data.write(to: url, options: .atomic)
                    onChange()
                } catch {
                    logger.error("Could not write the widget snapshot: \(error.localizedDescription, privacy: .public)")
                }
            }
        )
    }

    private static let logger = Logger(subsystem: "net.serby.Cards", category: "WidgetSnapshot")
}

private struct WidgetSnapshotKey: EnvironmentKey {
    static let defaultValue = WidgetSnapshot.live
}

public extension EnvironmentValues {
    var widgetSnapshot: WidgetSnapshot {
        get { self[WidgetSnapshotKey.self] }
        set { self[WidgetSnapshotKey.self] = newValue }
    }
}
