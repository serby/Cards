import CoreLocation
import SwiftUI

/// Where the location picker's map pin moves the place, through its
/// accessibility actions.
enum Compass: CaseIterable {
    case north, south, east, west

    var actionName: Text {
        switch self {
        case .north:
            Text("Move North", comment: "VoiceOver action on the Add Location map pin: moves the place north by the circle's radius.")
        case .south:
            Text("Move South", comment: "VoiceOver action on the Add Location map pin: moves the place south by the circle's radius.")
        case .east:
            Text("Move East", comment: "VoiceOver action on the Add Location map pin: moves the place east by the circle's radius.")
        case .west:
            Text("Move West", comment: "VoiceOver action on the Add Location map pin: moves the place west by the circle's radius.")
        }
    }

    var announcement: String {
        switch self {
        case .north:
            String(localized: "Moved north", comment: "VoiceOver announcement after the Move North action on the Add Location map pin.")
        case .south:
            String(localized: "Moved south", comment: "VoiceOver announcement after the Move South action on the Add Location map pin.")
        case .east:
            String(localized: "Moved east", comment: "VoiceOver announcement after the Move East action on the Add Location map pin.")
        case .west:
            String(localized: "Moved west", comment: "VoiceOver announcement after the Move West action on the Add Location map pin.")
        }
    }

    /// `coordinate` moved `distance` metres this way.
    func moving(_ coordinate: CLLocationCoordinate2D, by distance: CLLocationDistance) -> CLLocationCoordinate2D {
        let metresPerDegree = 111_320.0
        let latitudeStep = distance / metresPerDegree
        let longitudeStep = distance / (metresPerDegree * max(cos(coordinate.latitude * .pi / 180), 0.01))
        var target = coordinate
        switch self {
        case .north:
            target.latitude += latitudeStep
        case .south:
            target.latitude -= latitudeStep
        case .east:
            target.longitude += longitudeStep
        case .west:
            target.longitude -= longitudeStep
        }
        return target
    }
}

extension View {
    /// The location picker's pin and ring (`MapPinRing`, hidden from
    /// VoiceOver) as one element. VoiceOver cannot see the map under the pin
    /// or drag it, so the pin says what will be saved, `name` and `radius`,
    /// and moves by actions, which call `onMove`. The radius is spoken in
    /// `format`'s units.
    func voiceOverMapPin(
        name: String,
        radius: CLLocationDistance,
        in format: DistanceFormat,
        onMove: @escaping @MainActor (Compass) -> Void
    ) -> some View {
        ZStack {
            // At least a 44 pt target for VoiceOver and Switch Control, as the
            // pin alone is a narrow 14 pt: an element that ignores its children
            // takes their union as its frame, not the frame around them.
            Color.clear
                .frame(width: 44, height: 44)
            self
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("Map pin", comment: "VoiceOver label for the pin in the middle of the Add Location map, which marks the place to add.")
        )
        .accessibilityValue(CardLocationRow.spokenDescription(name: name, radius: radius, in: format))
        .accessibilityActions {
            ForEach(Compass.allCases, id: \.self) { direction in
                Button {
                    onMove(direction)
                } label: {
                    direction.actionName
                }
            }
        }
        .allowsHitTesting(false)
    }
}
