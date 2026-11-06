import CoreLocation
import MapKit
import Network

public extension PlaceSearch {
    /// Asks MapKit: its search completer for suggestions, its local search for
    /// the places they stand for, and its reverse geocoder for the name of a
    /// point. Results lean towards the region passed in, the map on screen.
    static let live = Self(
        suggest: { text, region in
            try await answering(emptyAs: []) {
                var seen = Set<String>()
                return try await SearchCompletions.results(for: text, in: region)
                    .map { PlaceSuggestion(query: text, title: $0.title, subtitle: $0.subtitle) }
                    .filter { seen.insert($0.id).inserted }
            }
        },
        place: { suggestion, region in
            try await answering(emptyAs: nil) {
                let completions = try await SearchCompletions.results(for: suggestion.query, in: region)
                // The same suggestion again, as MapKit gives the same answer to the same question.
                let request = if let completion = completions.first(where: {
                    $0.title == suggestion.title && $0.subtitle == suggestion.subtitle
                }) {
                    MKLocalSearch.Request(completion: completion)
                } else {
                    MKLocalSearch.Request(naturalLanguageQuery: "\(suggestion.title), \(suggestion.subtitle)")
                }
                return try await firstPlace(for: request, in: region, fallbackName: suggestion.title)
            }
        },
        bestMatch: { text, region in
            try await answering(emptyAs: nil) {
                // The top suggestion, as the person sees it; failing that, a plain search.
                let completion = try await SearchCompletions.results(for: text, in: region).first
                let request = if let completion {
                    MKLocalSearch.Request(completion: completion)
                } else {
                    MKLocalSearch.Request(naturalLanguageQuery: text)
                }
                return try await firstPlace(for: request, in: region, fallbackName: text)
            }
        },
        name: { coordinate in
            try await answering(emptyAs: nil) {
                try await placeName(at: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            }
        }
    )
}

private extension PlaceSearch {
    /// Runs a question to MapKit, turning "nothing found" errors into `empty`
    /// and every other failure into a `PlaceSearchError`. A failure while the
    /// device has no network is reported as offline, whatever MapKit called it.
    @MainActor
    static func answering<T>(emptyAs empty: T, _ question: @MainActor () async throws -> T) async throws -> T {
        do {
            return try await question()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let reason = PlaceSearchError(error)
            if reason != .offline, await isOffline() {
                throw PlaceSearchError.offline
            }
            guard let reason else { return empty }
            throw reason
        }
    }

    static func isOffline() async -> Bool {
        var paths = NWPathMonitor().makeAsyncIterator()
        guard let path = await paths.next() else { return false }
        return path.status != .satisfied
    }

    /// The first place a search finds, named as PLACE-10 says.
    @MainActor
    static func firstPlace(for request: MKLocalSearch.Request, in region: MKCoordinateRegion?, fallbackName: String) async throws -> PlaceMatch? {
        request.resultTypes = [.address, .pointOfInterest]
        if let region {
            request.region = region
        }
        guard let item = try await MKLocalSearch(request: request).start().mapItems.first else { return nil }
        let match = placeMatch(for: item)
        return PlaceMatch(name: match.name ?? fallbackName, latitude: match.coordinate.latitude, longitude: match.coordinate.longitude)
    }

    /// A map item's name and position. iOS 26 drops the placemark for an
    /// address, so each version reads the fields it has.
    @MainActor
    static func placeMatch(for item: MKMapItem) -> (name: String?, coordinate: CLLocationCoordinate2D) {
        let isPointOfInterest = item.pointOfInterestCategory != nil
        if #available(iOS 26, *) {
            let fields = PlaceFields(
                name: item.name,
                shortAddress: item.address?.shortAddress,
                cityName: item.addressRepresentations?.cityName,
                isPointOfInterest: isPointOfInterest
            )
            return (fields.placeName, item.location.coordinate)
        } else {
            let placemark = item.placemark
            let fields = PlaceFields(
                name: item.name,
                thoroughfare: placemark.thoroughfare,
                subLocality: placemark.subLocality,
                locality: placemark.locality,
                areasOfInterest: placemark.areasOfInterest ?? [],
                isPointOfInterest: isPointOfInterest
            )
            return (fields.placeName, placemark.coordinate)
        }
    }

    /// What to call the place at `location`: MapKit's reverse geocoder from iOS
    /// 26, and Core Location's before it.
    @MainActor
    static func placeName(at location: CLLocation) async throws -> String? {
        if #available(iOS 26, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let item = try await request.mapItems.first else { return nil }
            return placeMatch(for: item).name
        } else {
            guard let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
            return PlaceFields(
                name: placemark.name,
                thoroughfare: placemark.thoroughfare,
                subLocality: placemark.subLocality,
                locality: placemark.locality,
                areasOfInterest: placemark.areasOfInterest ?? [],
                isPointOfInterest: false
            ).placeName
        }
    }
}

/// One question to MapKit's search completer: what it suggests for some text.
/// A fresh completer per question keeps its non-Sendable results inside the
/// function that asked (rule 7); the picker waits for typing to pause first.
@MainActor
private final class SearchCompletions: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var continuation: CheckedContinuation<Void, any Error>?

    /// Addresses (streets, towns and postcodes among them) and points of
    /// interest such as shops, in or near `region` first.
    static func results(for text: String, in region: MKCoordinateRegion?) async throws -> [MKLocalSearchCompletion] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let request = SearchCompletions()
        try await request.ask(query, in: region)
        return request.completer.results
    }

    private func ask(_ query: String, in region: MKCoordinateRegion?) async throws {
        completer.resultTypes = [.address, .pointOfInterest]
        if let region {
            completer.region = region
        }
        completer.delegate = self
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                completer.queryFragment = query
            }
        } onCancel: {
            Task { @MainActor in
                self.completer.cancel()
                self.finish(throwing: CancellationError())
            }
        }
    }

    private func finish(throwing error: (any Error)? = nil) {
        guard let continuation else { return }
        self.continuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated { finish() }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        MainActor.assumeIsolated { finish(throwing: error) }
    }
}
