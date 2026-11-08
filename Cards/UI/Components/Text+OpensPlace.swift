import SwiftUI

extension Text {
    /// The VoiceOver hint for a place on the card screen that opens in `app`,
    /// in the top panel (PLACE-6) or the list of places (PLACE-9).
    static func opensPlace(in app: MapsApp) -> Text {
        switch app {
        case .appleMaps:
            Text(
                "Opens this place in Maps",
                comment: "VoiceOver hint for a place on a card's screen, in its top panel or its list of places. Maps is Apple's app."
            )
        case .googleMaps:
            Text(
                "Opens this place in Google Maps",
                comment: "VoiceOver hint for a place on a card's screen, in its top panel or its list of places, when Settings > Maps is Google Maps."
            )
        }
    }
}
