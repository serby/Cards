import CoreLocation
import MapKit
import SwiftUI

/// Finds places on the map and names them: suggestions as you type, the place
/// a suggestion stands for, the best match for what was typed, and a name for
/// any point. Injected, so nothing but the live value reaches MapKit.
public struct PlaceSearch: Sendable {
    /// Suggestions for what has been typed so far, those in or near `region`
    /// first. Empty when nothing matches.
    public var suggest: @MainActor @Sendable (_ text: String, _ region: MKCoordinateRegion?) async throws -> [PlaceSuggestion]
    /// The place a suggestion stands for, named as PLACE-10 says, or nil when
    /// MapKit no longer has it.
    public var place: @MainActor @Sendable (_ suggestion: PlaceSuggestion, _ region: MKCoordinateRegion?) async throws -> PlaceMatch?
    /// The best match for what was typed, for return pressed with no
    /// suggestion chosen, or nil when nothing matches.
    public var bestMatch: @MainActor @Sendable (_ text: String, _ region: MKCoordinateRegion?) async throws -> PlaceMatch?
    /// What to call the place at a point, such as a dropped pin (PLACE-10), or
    /// nil when MapKit has no name for it.
    public var name: @MainActor @Sendable (_ coordinate: CLLocationCoordinate2D) async throws -> String?

    public init(
        suggest: @escaping @MainActor @Sendable (_ text: String, _ region: MKCoordinateRegion?) async throws -> [PlaceSuggestion],
        place: @escaping @MainActor @Sendable (_ suggestion: PlaceSuggestion, _ region: MKCoordinateRegion?) async throws -> PlaceMatch?,
        bestMatch: @escaping @MainActor @Sendable (_ text: String, _ region: MKCoordinateRegion?) async throws -> PlaceMatch?,
        name: @escaping @MainActor @Sendable (_ coordinate: CLLocationCoordinate2D) async throws -> String?
    ) {
        self.suggest = suggest
        self.place = place
        self.bestMatch = bestMatch
        self.name = name
    }
}

public extension PlaceSearch {
    /// Suggests nothing, finds nothing and names nothing: the default for
    /// screens given no search, so a story never reaches MapKit by accident.
    static let unavailable = Self(
        suggest: { _, _ in [] },
        place: { _, _ in nil },
        bestMatch: { _, _ in nil },
        name: { _ in nil }
    )
}

/// A place MapKit suggests for what has been typed, shown as its title over
/// its subtitle, such as "Joe's Market Notting Hill" over its address.
public struct PlaceSuggestion: Identifiable, Hashable, Sendable {
    /// What had been typed when MapKit suggested it, so the live search can
    /// ask for it again when it is chosen.
    public let query: String
    public let title: String
    public let subtitle: String

    public init(query: String, title: String, subtitle: String) {
        self.query = query
        self.title = title
        self.subtitle = subtitle
    }

    /// MapKit never lists the same title and subtitle twice for one query, and
    /// the live search drops repeats in case it does.
    public var id: String { "\(title)\n\(subtitle)" }
}

/// Why a search could not be answered. Finding nothing is not an error: it is
/// an empty list or a nil place.
public enum PlaceSearchError: Error, Equatable, Sendable {
    /// The device is offline, so MapKit could not be asked.
    case offline
    /// MapKit could not answer, because its servers failed or it asked the app
    /// to search less often.
    case unavailable

    /// Sorts an error from MapKit or Core Location: nil when it only means that
    /// nothing was found, `.offline` when the network was the problem.
    public init?(_ error: any Error) {
        let error = error as NSError
        if Self.isNetworkFailure(error) {
            self = .offline
            return
        }
        switch (error.domain, error.code) {
        case (MKError.errorDomain, Int(MKError.Code.placemarkNotFound.rawValue)),
             (kCLErrorDomain, CLError.Code.geocodeFoundNoResult.rawValue),
             (kCLErrorDomain, CLError.Code.geocodeFoundPartialResult.rawValue):
            return nil
        default:
            self = .unavailable
        }
    }

    /// Whether the error, or one it wraps, is the network failing.
    private static func isNetworkFailure(_ error: NSError) -> Bool {
        switch error.domain {
        case NSURLErrorDomain where offlineCodes.contains(error.code),
             kCLErrorDomain where error.code == CLError.Code.network.rawValue:
            return true
        default:
            return (error.userInfo[NSUnderlyingErrorKey] as? NSError).map(isNetworkFailure) ?? false
        }
    }

    private static let offlineCodes: Set<Int> = [
        NSURLErrorNotConnectedToInternet,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorCannotFindHost,
        NSURLErrorCannotConnectToHost,
        NSURLErrorDNSLookupFailed,
        NSURLErrorTimedOut,
        NSURLErrorDataNotAllowed,
        NSURLErrorInternationalRoamingOff
    ]
}

private struct PlaceSearchKey: EnvironmentKey {
    static let defaultValue = PlaceSearch.live
}

public extension EnvironmentValues {
    var placeSearch: PlaceSearch {
        get { self[PlaceSearchKey.self] }
        set { self[PlaceSearchKey.self] = newValue }
    }
}
