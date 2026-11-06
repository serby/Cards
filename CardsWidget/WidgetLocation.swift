import CoreLocation

/// One location fix for a widget refresh, injected into the timeline provider so
/// only the live value reaches location services.
struct WidgetLocation: Sendable {
    /// Where you are, or nil when the widget may not use your location or no
    /// fix arrives in time.
    var current: @MainActor @Sendable () async -> CLLocation?
}

extension WidgetLocation {
    static let maximumAge: TimeInterval = 2 * 60
    static let timeout: Duration = .seconds(10)

    /// Uses a recent cached fix when there is one, and otherwise waits a few
    /// seconds for a new one before giving up.
    static let live = Self {
        let manager = CLLocationManager()
        guard manager.isAuthorizedForWidgetUpdates else { return nil }
        if let cached = manager.location, -cached.timestamp.timeIntervalSinceNow < maximumAge {
            return cached
        }
        return await fresh(within: timeout) ?? manager.location
    }

    @MainActor
    private static func fresh(within timeout: Duration) async -> CLLocation? {
        await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask {
                do {
                    // An update without a location (no fix yet) keeps waiting.
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let location = update.location { return location }
                    }
                } catch {
                    // Location services failed; fall back to the cached fix.
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
