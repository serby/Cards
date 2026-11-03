import SwiftUI

/// One of a card's locations in the edit form: its name and radius, lined up
/// with the form's other icon rows.
public struct CardLocationRow: View {
    private let location: CardLocation

    public init(_ location: CardLocation) {
        self.location = location
    }

    public var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .lineLimit(1)
                Text("\(location.radius.radiusText) radius")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

#Preview {
    List {
        CardLocationRow(.sample)
    }
}
