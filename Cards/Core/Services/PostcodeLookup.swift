import CoreLocation

/// Turns a postcode (or any address text) into a place on the map.
public enum PostcodeLookup {
    /// The first match for `query`, or `nil` if nothing was found.
    public static func find(_ query: String) async -> PlaceMatch? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let placemarks = try? await CLGeocoder().geocodeAddressString(trimmed),
              let coordinate = placemarks.first?.location?.coordinate else {
            return nil
        }
        return PlaceMatch(name: trimmed.uppercased(), latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
