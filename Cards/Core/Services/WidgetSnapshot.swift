import Foundation
import OSLog
import WidgetKit

/// The cards as the Home Screen widget sees them: a JSON file in the App Group
/// container that the app rewrites whenever its cards change.
public enum WidgetSnapshot {
    public static let appGroup = "group.net.serby.Cards"
    public static let widgetKind = "CardWidget"

    private static let logger = Logger(subsystem: "net.serby.Cards", category: "WidgetSnapshot")

    /// Where the snapshot lives, or nil if the App Group is missing from the
    /// entitlements.
    public static var defaultURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "widget-cards.json")
    }

    /// The cards last written, in list order. Empty when there is no snapshot yet
    /// or it cannot be read, which the widget shows as "no cards".
    public static func read(from url: URL? = defaultURL) -> [WidgetCard] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([WidgetCard].self, from: data)) ?? []
    }

    /// Writes `cards` and returns whether the file changed.
    @discardableResult
    public static func write(_ cards: [WidgetCard], to url: URL? = defaultURL) throws -> Bool {
        guard let url else { return false }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(cards)
        guard data != (try? Data(contentsOf: url)) else { return false }
        try data.write(to: url, options: .atomic)
        return true
    }

    /// Writes `cards` and asks WidgetKit to redraw if anything changed.
    public static func publish(_ cards: [WidgetCard]) {
        do {
            if try write(cards) {
                WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
            }
        } catch {
            logger.error("Could not write the widget snapshot: \(error.localizedDescription, privacy: .public)")
        }
    }
}
