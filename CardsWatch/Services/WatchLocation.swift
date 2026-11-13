import CoreLocation
import SwiftUI

/// Where the watch is, from its own Core Location (WATCH-4), injected so only
/// the live value reaches location services.
struct WatchLocation: Sendable {
    /// Where you are, or nil when the app may not use your location or no fix
    /// arrives in time.
    var current: @MainActor @Sendable () async -> CLLocation?
}

extension WatchLocation {
    /// A reading this recent is used as it is, as the widget does (WID-1).
    static let maximumAge: TimeInterval = 2 * 60
    /// How long to wait for a new reading before showing the list without one.
    static let timeout: Duration = .seconds(10)

    /// Asks for When In Use access the first time, then uses a recent cached
    /// reading when there is one and otherwise waits a few seconds for a new one.
    static let live = Self {
        let manager = CLLocationManager()
        switch manager.authorizationStatus {
        case .denied, .restricted:
            return nil
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
        if let cached = manager.location, -cached.timestamp.timeIntervalSinceNow < maximumAge {
            return cached
        }
        let reading = await WatchLocation.fresh(within: timeout)
        // Kept until the reading is in, so a prompt it raised stays up.
        withExtendedLifetime(manager) {}
        return reading
    }

    /// The first reading Core Location gives within `timeout`, or nil.
    private static func fresh(within timeout: Duration) async -> CLLocation? {
        await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask {
                do {
                    // An update without a location (no fix yet) keeps waiting.
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let location = update.location {
                            return location
                        }
                    }
                } catch {
                    // Cancelled, or the updates failed: no reading this time.
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next().flatMap { $0 }
            group.cancelAll()
            return first
        }
    }
}

private struct WatchLocationKey: EnvironmentKey {
    static let defaultValue = WatchLocation.live
}

extension EnvironmentValues {
    var watchLocation: WatchLocation {
        get { self[WatchLocationKey.self] }
        set { self[WatchLocationKey.self] = newValue }
    }
}
