import SwiftUI

/// One of a card's locations in the edit form: its name and radius, lined up
/// with the form's other icon rows.
public struct CardLocationRow: View {
    private let location: CardLocation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(_ location: CardLocation) {
        self.location = location
    }

    public var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    // The whole name at accessibility sizes, where one line holds
                    // only a few letters.
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                Text(
                    "\(location.radius.metres, format: .radius) radius",
                    comment: "Under a location's name in the card form: the size of the circle around the place, as in “200 m radius”."
                )
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(Color.accent)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}
