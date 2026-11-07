import CoreLocation
import Observation

/// The user's current location, for card distances and the map picker. It only
/// asks for permission when a feature needs it, and only updates when started.
@MainActor
@Observable
public final class LocationService: NSObject {
    public private(set) var current: CLLocation?
    public private(set) var authorization: CLAuthorizationStatus

    @ObservationIgnored private let manager: CLLocationManager
    @ObservationIgnored private var wantsUpdates = false
    @ObservationIgnored private let fixedLocation: CLLocation?

    /// With `fixedLocation`, the service reports that place and never uses
    /// location services, so what it shows does not depend on where the device is.
    /// Otherwise the permission starts as not determined and arrives in
    /// `locationManagerDidChangeAuthorization`, which iOS calls as soon as the
    /// delegate is set. Reading `authorizationStatus` here asked location
    /// services on the main thread and waited for the answer, during launch:
    /// on a freshly booted simulator that held the first launch for four minutes.
    public init(fixedLocation: CLLocation? = nil) {
        let manager = CLLocationManager()
        self.manager = manager
        self.fixedLocation = fixedLocation
        current = fixedLocation
        authorization = fixedLocation == nil ? .notDetermined : .authorizedWhenInUse
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 25
    }

    public var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    /// Asks for When In Use permission if it has not been asked yet, then starts.
    public func requestAccess() {
        wantsUpdates = true
        if fixedLocation == nil, authorization == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            start()
        }
    }

    /// Starts updates if permission is already granted. Never prompts.
    public func start() {
        wantsUpdates = true
        guard fixedLocation == nil, isAuthorized else { return }
        manager.startUpdatingLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            authorization = status
            if wantsUpdates { start() }
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        MainActor.assumeIsolated { current = latest }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // Transient failures (no fix yet, airplane mode) keep the last known location.
    }
}
