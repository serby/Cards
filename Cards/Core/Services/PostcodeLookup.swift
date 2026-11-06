import CoreLocation
import SwiftUI

/// Turns a postcode (or any address text) into a place on the map, injected so
/// nothing but the live value reaches Apple's geocoder.
public struct PostcodeLookup: Sendable {
    /// The first match for a query, or `nil` if nothing was found.
    public var find: @Sendable (String) async -> PlaceMatch?

    public init(find: @escaping @Sendable (String) async -> PlaceMatch?) {
        self.find = find
    }
}

public extension PostcodeLookup {
    /// Asks Apple's geocoder.
    static let live = Self { query in
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let placemarks = try? await CLGeocoder().geocodeAddressString(trimmed),
              let coordinate = placemarks.first?.location?.coordinate else {
            return nil
        }
        return PlaceMatch(name: trimmed.uppercased(), latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

private struct PostcodeLookupKey: EnvironmentKey {
    static let defaultValue = PostcodeLookup.live
}

public extension EnvironmentValues {
    var postcodeLookup: PostcodeLookup {
        get { self[PostcodeLookupKey.self] }
        set { self[PostcodeLookupKey.self] = newValue }
    }
}
