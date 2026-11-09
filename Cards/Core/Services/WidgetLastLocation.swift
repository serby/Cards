import CoreLocation
import Foundation
import OSLog

/// The widget's last good location reading, kept in a JSON file in the App
/// Group container. iOS only gives a widget your location for about 15 minutes
/// after it was last on screen; after that Core Location reports it
/// "insufficiently in use" and gives it nothing, not even the device's last
/// reading. A reload then picks the card for where you were last seen, from
/// this, instead of the top card (WID-1). Injected, so only the live value
/// reaches the App Group.
public struct WidgetLastLocation: Sendable {
    /// The reading last kept, or nil when there is none or it cannot be read.
    public var read: @Sendable () -> CLLocation?
    /// Keeps `location`, unless the reading already kept is newer. A failure is
    /// logged.
    public var write: @Sendable (CLLocation) -> Void

    public init(read: @escaping @Sendable () -> CLLocation?, write: @escaping @Sendable (CLLocation) -> Void) {
        self.read = read
        self.write = write
    }
}

public extension WidgetLastLocation {
    /// The file in the App Group container.
    static let live = file(
        at: FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)?
            .appending(path: "widget-location.json")
    )

    /// A reading kept in the JSON file at `url`. With no `url` (the App Group is
    /// missing from the entitlements) it reads nothing and keeps nothing.
    static func file(at url: URL?) -> Self {
        let read: @Sendable () -> CLLocation? = {
            guard let url, let data = try? Data(contentsOf: url) else { return nil }
            return (try? JSONDecoder().decode(Stored.self, from: data))?.location
        }
        return Self(
            read: read,
            write: { location in
                guard let url else { return }
                if let kept = read(), kept.timestamp >= location.timestamp { return }
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .sortedKeys
                    try encoder.encode(Stored(location)).write(to: url, options: .atomic)
                } catch {
                    logger.error("Could not keep the widget's location: \(error.localizedDescription, privacy: .public)")
                }
            }
        )
    }

    /// The reading a reload should use: a new one when it got one, or else the
    /// newer of the device's last reading and the one kept, so a reload iOS
    /// gives no location still knows where you were last seen.
    static func best(new: CLLocation?, deviceLast: CLLocation?, kept: CLLocation?) -> CLLocation? {
        if let new { return new }
        guard let deviceLast else { return kept }
        guard let kept else { return deviceLast }
        return deviceLast.timestamp >= kept.timestamp ? deviceLast : kept
    }

    private static let logger = Logger(subsystem: "net.serby.Cards", category: "WidgetLastLocation")
}

/// The file's contents: where, how accurately, and when.
private struct Stored: Codable {
    var latitude: Double
    var longitude: Double
    var accuracy: Double
    var timestamp: Date

    init(_ location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        accuracy = location.horizontalAccuracy
        timestamp = location.timestamp
    }

    var location: CLLocation? {
        guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) else { return nil }
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: -1,
            timestamp: timestamp
        )
    }
}
