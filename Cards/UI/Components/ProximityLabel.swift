import SwiftUI

/// How far away a card's nearest location is: "Here", or "350 m".
/// With `showsPlace`, it names the place too: "At Westway", "350 m · Westway".
public struct ProximityLabel: View {
    private let proximity: CardProximity
    private let showsPlace: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(_ proximity: CardProximity, showsPlace: Bool = false) {
        self.proximity = proximity
        self.showsPlace = showsPlace
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: proximity.isHere ? "location.fill" : "location")
                .imageScale(.small)
            text
        }
        .fontWeight(proximity.isHere ? .semibold : nil)
        .padding(.horizontal, proximity.isHere ? 8 : 0)
        .background {
            if proximity.isHere {
                // Drawn beyond the text vertically so "Here" never makes a row taller.
                Capsule().fill(.quaternary).padding(.vertical, -3)
            }
        }
        .monospacedDigit()
        // One line keeps rows tidy, but at accessibility sizes it would leave
        // only a few letters of the place's name.
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
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
                comment: "On a card's screen when the user is inside one of the card's locations. The argument is the place's name, such as Westway."
            )
        case (false, false):
            Text(distance, format: .distance)
        case (false, true):
            Text(
                "\(distance, format: .distance) · \(proximity.placeName)",
                comment: "On a card's screen: the distance to the card's nearest location, then the place's name, as in “350 m · Westway”."
            )
        }
    }

    private var accessibilityText: Text {
        if proximity.isHere {
            Text(
                "You're at \(proximity.placeName)",
                comment: "VoiceOver label when the user is inside one of a card's locations. The argument is the place's name, such as Westway."
            )
        } else {
            Text(
                "\(distance, format: .spokenDistance) from \(proximity.placeName)",
                comment: "VoiceOver label: how far the user is from a card's nearest location, in full, as in “350 metres from Westway”."
            )
        }
    }

    private var distance: Measurement<UnitLength> {
        proximity.distance.metres
    }
}
