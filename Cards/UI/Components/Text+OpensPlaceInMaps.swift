import SwiftUI

extension Text {
    /// The VoiceOver hint for a place on the card screen that opens in Maps,
    /// in the top panel (PLACE-6) or the list of places (PLACE-9).
    static var opensPlaceInMaps: Text {
        Text(
            "Opens this place in Maps",
            comment: "VoiceOver hint for a place on a card's screen, in its top panel or its list of places. Maps is Apple's app."
        )
    }
}
