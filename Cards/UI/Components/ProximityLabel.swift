import SwiftUI

/// How far away a card's nearest location is: "Here", or "350 m".
/// With `showsPlace`, it names the place too: "At Boulder Barn", "350 m · Boulder Barn".
/// "Here" stands out in its own capsule unless `highlightsHere` is off, for
/// callers that already put the label on a capsule of its own. Distances are in
/// the units chosen in Settings (`distanceFormat`, SET-4).
public struct ProximityLabel: View {
    private let proximity: CardProximity
    private let showsPlace: Bool
    private let highlightsHere: Bool
    @Environment(\.distanceFormat) private var distanceFormat

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
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(proximity.spokenDescription(in: distanceFormat))
    }
}

public extension CardProximity {
    /// What a label shows: "Here", "At Boulder Barn", "350 m", or with the place,
    /// "350 m · Boulder Barn".
    func text(showsPlace: Bool, in format: DistanceFormat) -> String {
        switch (isHere, showsPlace) {
        case (true, false):
            String(localized: "Here")
        case (true, true):
            String(localized: "At \(placeName)")
        case (false, false):
            format.distance(distance)
        case (false, true):
            String(localized: "\(format.distance(distance)) · \(placeName)")
        }
    }

    /// What VoiceOver says for the distance: "You're at Joe's Market Notting
    /// Hill", or "350 m from Boulder Barn". Anything that shows a distance reads
    /// it this way.
    func spokenDescription(in format: DistanceFormat) -> String {
        isHere
            ? String(localized: "You're at \(placeName)")
            : String(localized: "\(format.distance(distance)) from \(placeName)")
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
