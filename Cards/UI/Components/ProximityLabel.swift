import SwiftUI

/// How far away a card's nearest location is: "Here", or "350 m".
/// With `showsPlace`, it names the place too: "At Boulder Barn", "350 m · Boulder Barn".
/// "Here" stands out in its own capsule unless `highlightsHere` is off, for
/// callers that already put the label on a capsule of its own. Distances are in
/// the units chosen in Settings (`distanceFormat`, SET-4).
/// It keeps to one line, except at the accessibility text sizes, unless
/// `wraps` is on, for a screen that shows everything at every size.
public struct ProximityLabel: View {
    private let proximity: CardProximity
    private let showsPlace: Bool
    private let highlightsHere: Bool
    private let wraps: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.distanceFormat) private var distanceFormat

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
            Text(proximity.text(showsPlace: showsPlace, in: distanceFormat))
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
        .accessibilityLabel(proximity.spokenDescription(in: distanceFormat))
    }
}

public extension CardProximity {
    /// What a label shows: "Here", "At Boulder Barn", "350 m", or with the place,
    /// "350 m · Boulder Barn". Resolved in the app's language; the distance's
    /// numbers follow the format's locale.
    func text(showsPlace: Bool, in format: DistanceFormat) -> String {
        switch (isHere, showsPlace) {
        case (true, false):
            String(
                localized: "Here",
                comment: "Shown on a card in the list instead of a distance when the user is inside one of the card's locations. Keep it very short."
            )
        case (true, true):
            String(
                localized: "At \(placeName)",
                comment: """
                    On a card's screen when the user is inside one of the card's locations. \
                    The argument is the place's name, such as Boulder Barn.
                    """
            )
        case (false, false):
            format.distance(distance)
        case (false, true):
            String(
                localized: "\(format.distance(distance)) · \(placeName)",
                comment: "On a card's screen: the distance to the card's nearest location, then the place's name, as in “350 m · Boulder Barn”."
            )
        }
    }

    /// What VoiceOver says for the distance, with the units in full: "You're at
    /// Joe's Market Notting Hill", or "350 metres from Boulder Barn". Anything
    /// that shows a distance reads it this way.
    func spokenDescription(in format: DistanceFormat) -> String {
        isHere
            ? String(
                localized: "You're at \(placeName)",
                comment: "VoiceOver label when the user is inside one of a card's locations. The argument is the place's name, such as Boulder Barn."
            )
            : String(
                localized: "\(format.distance(distance, width: .wide)) from \(placeName)",
                comment: "VoiceOver label: how far the user is from a card's nearest location, in full, as in “350 metres from Boulder Barn”."
            )
    }
}

#if DEBUG
#Preview("Automatic") {
    VStack(alignment: .leading, spacing: 12) {
        ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 0))
        ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 0), showsPlace: true)
        ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 350))
        ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 4_200), showsPlace: true)
    }
}

#Preview("Kilometres and miles") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach([DistanceUnits.kilometres, .miles], id: \.self) { units in
            Group {
                ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 350))
                ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 4_200), showsPlace: true)
            }
            .environment(\.distanceUnits, units)
        }
    }
}
#endif
