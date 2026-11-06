import SwiftUI

/// How far away a card's nearest location is: "Here", or "350 m".
/// With `showsPlace`, it names the place too: "At Boulder Barn", "350 m · Boulder Barn".
/// "Here" stands out in its own capsule unless `highlightsHere` is off, for
/// callers that already put the label on a capsule of its own.
/// It keeps to one line, except at the accessibility text sizes, unless
/// `wraps` is on, for a screen that shows everything at every size.
public struct ProximityLabel: View {
    private let proximity: CardProximity
    private let showsPlace: Bool
    private let highlightsHere: Bool
    private let wraps: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(_ proximity: CardProximity, showsPlace: Bool = false, highlightsHere: Bool = true, wraps: Bool = false) {
        self.proximity = proximity
        self.showsPlace = showsPlace
        self.highlightsHere = highlightsHere
        self.wraps = wraps
    }

    private var drawsCapsule: Bool { proximity.isHere && highlightsHere }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: proximity.isHere ? "location.fill" : "location")
                .imageScale(.small)
            text
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
        // One line keeps rows tidy, but at accessibility sizes it would leave
        // only a few letters of the place's name.
        .lineLimit(wraps || dynamicTypeSize.isAccessibilitySize ? nil : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(proximity.spokenDescription)
    }

    private var text: Text {
        switch (proximity.isHere, showsPlace) {
        case (true, false):
            Text(
                "Here",
                comment: "Shown on a card in the list instead of a distance when the user is inside one of the card's locations. Keep it very short."
            )
        case (true, true):
            Text(
                "At \(proximity.placeName)",
                comment: """
                    On a card's screen when the user is inside one of the card's locations. \
                    The argument is the place's name, such as Boulder Barn.
                    """
            )
        case (false, false):
            Text(distance, format: .distance)
        case (false, true):
            Text(
                "\(distance, format: .distance) · \(proximity.placeName)",
                comment: "On a card's screen: the distance to the card's nearest location, then the place's name, as in “350 m · Boulder Barn”."
            )
        }
    }

    private var distance: Measurement<UnitLength> {
        proximity.distance.metres
    }
}

public extension CardProximity {
    /// What VoiceOver says for the distance: "You're at Boulder Barn", or
    /// "350 metres from Boulder Barn", with the unit written out. Anything that
    /// shows a distance reads it this way.
    var spokenDescription: Text {
        if isHere {
            Text(
                "You're at \(placeName)",
                comment: "VoiceOver label when the user is inside one of a card's locations. The argument is the place's name, such as Boulder Barn."
            )
        } else {
            Text(
                "\(distance.metres, format: .spokenDistance) from \(placeName)",
                comment: "VoiceOver label: how far the user is from a card's nearest location, in full, as in “350 metres from Boulder Barn”."
            )
        }
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
