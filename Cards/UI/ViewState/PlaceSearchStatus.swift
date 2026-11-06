import Foundation

/// What the location picker shows below its search field: MapKit's
/// suggestions, or a few words when it has none to give (PLACE-2).
public enum PlaceSearchStatus: Equatable, Sendable {
    /// Waiting for the first suggestions for what was typed.
    case searching
    /// MapKit's suggestions, best first.
    case found([PlaceSuggestion])
    /// MapKit has nothing for the text.
    case notFound(String)
    /// MapKit could not be asked, or could not answer.
    case failed(PlaceSearchError)

    /// MapKit's answer to `text`: its suggestions, or "no place found" when
    /// there are none.
    public static func answer(_ suggestions: [PlaceSuggestion], to text: String) -> Self {
        suggestions.isEmpty ? .notFound(text) : .found(suggestions)
    }

    /// The status for a failed search: `error` as a `PlaceSearchError`, or as
    /// search not working when it is something else.
    public static func failure(_ error: any Error) -> Self {
        .failed((error as? PlaceSearchError) ?? .unavailable)
    }

    /// The words shown, and read by VoiceOver, when there is no list to show.
    public var message: String? {
        switch self {
        case .searching:
            "Searching\u{2026}"
        case .found:
            nil
        case .notFound(let text):
            "No place found for \u{201C}\(text.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}"
        case .failed(.offline):
            "You are offline. Connect to the internet to search, or drag the map to the place."
        case .failed(.unavailable):
            "Search is not working right now. Try again, or drag the map to the place."
        }
    }
}
