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

    /// Uses a recent cached reading when there is one, and otherwise waits a
    /// few seconds for a new one. Without one, as when iOS no longer counts the
    /// widget in use, it uses the newer of the device's last reading and the
    /// one `lastLocation` kept, and keeps each good reading for next time. Each
    /// step goes to `log`.
    static func live(log: WidgetLog, lastLocation: WidgetLastLocation = .live) -> Self {
        Self {
            let manager = CLLocationManager()
            log.write("location: \(permission(of: manager))")
            guard manager.isAuthorizedForWidgetUpdates else { return nil }
            if let cached = manager.location {
                if -cached.timestamp.timeIntervalSinceNow < maximumAge {
                    log.write("location: using the cached fix, \(cached.logDescription)")
                    lastLocation.write(cached)
                    return cached
                }
                log.write("location: the cached fix is too old, \(cached.logDescription)")
            } else {
                log.write("location: no cached fix")
            }
            if let fresh = await fresh(within: timeout, log: log) {
                lastLocation.write(fresh)
                return fresh
            }
            let deviceLast = manager.location
            let kept = lastLocation.read()
            guard let best = WidgetLastLocation.best(new: nil, deviceLast: deviceLast, kept: kept) else {
                log.write("location: no fix at all, and none kept")
                return nil
            }
            if best === deviceLast {
                log.write("location: falling back to the device's last fix, \(best.logDescription)")
                lastLocation.write(best)
            } else {
                log.write("location: using the kept fix, \(best.logDescription)")
            }
            return best
        }
    }

    @MainActor
    private static func fresh(within timeout: Duration, log: WidgetLog) async -> CLLocation? {
        let started = ContinuousClock.now
        let elapsed: @Sendable () -> String = {
            (ContinuousClock.now - started).formatted(.units(allowed: [.seconds, .milliseconds], width: .narrow))
        }
        return await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask {
                var count = 0
                do {
                    // An update without a location (no fix yet) keeps waiting.
                    for try await update in CLLocationUpdate.liveUpdates() {
                        count += 1
                        if let location = update.location {
                            log.write("location: new fix in update \(count) after \(elapsed()), \(location.logDescription)\(flags(of: update))")
                            return location
                        }
                        if count <= 10 {
                            log.write("location: update \(count) after \(elapsed()) has no location\(flags(of: update))")
                        }
                    }
                    log.write("location: updates ended after \(elapsed()) and \(count) updates, none with a location")
                } catch is CancellationError {
                    log.write("location: gave up after \(elapsed()) and \(count) updates, none with a location")
                } catch {
                    log.write("location: updates failed after \(elapsed()): \(error.localizedDescription)")
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

    private static func permission(of manager: CLLocationManager) -> String {
        let status = switch manager.authorizationStatus {
        case .notDetermined:
            "not asked"
        case .restricted:
            "restricted"
        case .denied:
            "denied"
        case .authorizedAlways:
            "always"
        case .authorizedWhenInUse:
            "while using"
        @unknown default:
            "unknown (\(manager.authorizationStatus.rawValue))"
        }
        let accuracy = manager.accuracyAuthorization == .fullAccuracy ? "precise" : "approximate"
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled ? ", Low Power Mode on" : ""
        return "widget may use it: \(manager.isAuthorizedForWidgetUpdates ? "yes" : "no"), app permission \(status), \(accuracy)\(lowPower)"
    }

    /// The diagnostics Core Location attaches to an update, such as why it has
    /// no location.
    private static func flags(of update: CLLocationUpdate) -> String {
        let flags = [
            update.stationary ? "stationary" : nil,
            update.locationUnavailable ? "location unavailable" : nil,
            update.insufficientlyInUse ? "insufficiently in use" : nil,
            update.serviceSessionRequired ? "service session required" : nil,
            update.accuracyLimited ? "accuracy limited" : nil,
            update.authorizationDenied ? "authorisation denied" : nil,
            update.authorizationDeniedGlobally ? "location services off" : nil,
            update.authorizationRestricted ? "authorisation restricted" : nil,
            update.authorizationRequestInProgress ? "authorisation request in progress" : nil
        ].compactMap(\.self)
        return flags.isEmpty ? "" : " [\(flags.joined(separator: ", "))]"
    }
}
