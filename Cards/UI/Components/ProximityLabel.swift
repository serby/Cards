import SwiftUI

/// How far away a card's nearest location is: "Here", or "350 m".
/// With `showsPlace`, it names the place too: "At Boulder Barn", "350 m · Boulder Barn".
/// "Here" stands out in its own capsule unless `highlightsHere` is off, for
/// callers that already put the label on a capsule of its own.
public struct ProximityLabel: View {
    private let proximity: CardProximity
    private let showsPlace: Bool
    private let highlightsHere: Bool

    public init(_ proximity: CardProximity, showsPlace: Bool = false, highlightsHere: Bool = true) {
        self.proximity = proximity
        self.showsPlace = showsPlace
        self.highlightsHere = highlightsHere
    }

    private var drawsCapsule: Bool { proximity.isHere && highlightsHere }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: proximity.isHere ? "location.fill" : "location")
                .imageScale(.small)
            Text(text)
        }
        .fontWeight(proximity.isHere ? .semibold : nil)
        .padding(.horizontal, drawsCapsule ? 8 : 0)
        .background {
            if drawsCapsule {
                // Drawn beyond the text vertically so "Here" never makes a row taller.
                Capsule().fill(.quaternary).padding(.vertical, -3)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(proximity.spokenDescription)
    }

    private var text: String {
        switch (proximity.isHere, showsPlace) {
        case (true, false):
            "Here"
        case (true, true):
            "At \(proximity.placeName)"
        case (false, false):
            distance
        case (false, true):
            "\(distance) · \(proximity.placeName)"
        }
    }

    private var distance: String {
        proximity.distance.distanceText
    }
}

public extension CardProximity {
    /// What VoiceOver says for the distance: "You're at Joe's Market Notting Hill",
    /// or "350 m from Boulder Barn". Anything that shows a distance reads it this way.
    var spokenDescription: String {
        isHere ? "You're at \(placeName)" : "\(distance.distanceText) from \(placeName)"
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 0))
        ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 0), showsPlace: true)
        ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 350))
        ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 4_200), showsPlace: true)
    }
}
#endif
