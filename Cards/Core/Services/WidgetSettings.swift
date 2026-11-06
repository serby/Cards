import Foundation
import OSLog
import WidgetKit

/// The Settings choices the Home Screen widget follows. The widget cannot read
/// the app's settings, so the app copies them to a JSON file in the App Group
/// container, beside the cards (`WidgetSnapshot`), and the widget reads them
/// from there (WID-7). Today that is the Distances choice (SET-4). Injected, so
/// only the live value reaches the App Group and WidgetKit.
public struct WidgetSettings: Sendable {
    /// The units to show distances in: the last choice copied, or Automatic
    /// when there is no copy yet or it cannot be read.
    public var distanceUnits: @Sendable () -> DistanceUnits
    /// Copies the Distances choice and, if that changed the file, asks
    /// WidgetKit to redraw the widget. A failure is logged.
    public var setDistanceUnits: @Sendable (DistanceUnits) -> Void

    public init(
        distanceUnits: @escaping @Sendable () -> DistanceUnits,
        setDistanceUnits: @escaping @Sendable (DistanceUnits) -> Void
    ) {
        self.distanceUnits = distanceUnits
        self.setDistanceUnits = setDistanceUnits
    }
}

public extension WidgetSettings {
    /// The file in the App Group container, shared by the app and the widget.
    static let live = file(
        at: FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)?
            .appending(path: "widget-settings.json"),
        onChange: { WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind) }
    )

    /// Settings kept in the JSON file at `url`, calling `onChange` after a write
    /// that changed the file. With no `url` (the App Group is missing from the
    /// entitlements) it reads Automatic and writes nothing.
    static func file(at url: URL?, onChange: @escaping @Sendable () -> Void = {}) -> Self {
        Self(
            distanceUnits: {
                guard let url, let data = try? Data(contentsOf: url) else { return .automatic }
                return DistanceUnits.stored(try? JSONDecoder().decode(Stored.self, from: data).distanceUnits)
            },
            setDistanceUnits: { units in
                guard let url else { return }
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .sortedKeys
                    let data = try encoder.encode(Stored(distanceUnits: units.rawValue))
                    guard data != (try? Data(contentsOf: url)) else { return }
                    try data.write(to: url, options: .atomic)
                    onChange()
                } catch {
                    logger.error("Could not write the widget settings: \(error.localizedDescription, privacy: .public)")
                }
            }
        )
    }

    private static let logger = Logger(subsystem: "net.serby.Cards", category: "WidgetSettings")
}

/// The file's contents. The units are a raw value, read tolerantly, so a choice
/// written by a newer build falls back to Automatic.
private struct Stored: Codable {
    var distanceUnits: String?
}
