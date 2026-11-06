import SwiftUI

/// One of a card's locations in the edit form: its name and radius, lined up
/// with the form's other icon rows. The radius is in the units chosen in
/// Settings (SET-4).
public struct CardLocationRow: View {
    private let location: CardLocation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.distanceFormat) private var distanceFormat

    public init(_ location: CardLocation) {
        self.location = location
    }

    public var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // At these sizes a Label runs text after its first line back
                // under the icon, which started the radius part-way along one
                // line and at the edge on the next. A column of its own keeps
                // every line of both at one edge.
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    icon
                    text
                        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                }
            } else {
                Label {
                    text
                } icon: {
                    icon
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spokenDescription(name: location.name, radius: location.radius, in: distanceFormat))
        .accessibilityIdentifier("locationRow")
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(location.name)
                // The whole name at accessibility sizes, where one line holds
                // only a few letters.
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            Text(
                "\(distanceFormat.radius(location.radius)) radius",
                comment: "Under a location's name in the card form: the size of the circle around the place, as in “200 m radius”."
            )
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
                .monospacedDigit()
        }
    }

    private var icon: some View {
        Image(systemName: "mappin.circle.fill")
            .foregroundStyle(Color.accent)
            .accessibilityHidden(true)
    }

    /// A place as VoiceOver reads it, with the unit in words, as "200 m" is
    /// spoken differently from one language to another. The location
    /// picker's map pin reads the same.
    static func spokenDescription(name: String, radius: Double, in format: DistanceFormat) -> Text {
        Text(
            "\(name), \(format.radius(radius, width: .wide)) radius",
            comment: """
            VoiceOver label for a place: its name, then the size of the circle around it, as in “Boulder Barn, 200 metres radius”. \
            Read for a place in the card form and for the pin on the Add Location map.
            """
        )
    }
}

#if DEBUG
#Preview {
    List {
        CardLocationRow(.sample)
    }
}

#Preview("In yards") {
    List {
        CardLocationRow(.sample)
    }
    .environment(\.distanceUnits, .miles)
}
#endif
