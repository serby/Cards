import CoreLocation

/// One location fix for a widget refresh. Uses a recent cached fix when there is
/// one, and otherwise waits a few seconds for a new one before giving up.
@MainActor
enum WidgetLocation {
    static let maximumAge: TimeInterval = 5 * 60
    static let timeout: Duration = .seconds(10)

    static func current() async -> CLLocation? {
        let manager = CLLocationManager()
        guard manager.isAuthorizedForWidgetUpdates else { return nil }
        if let cached = manager.location, -cached.timestamp.timeIntervalSinceNow < maximumAge {
            return cached
        }
        return await fresh(within: timeout) ?? manager.location
    }

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
