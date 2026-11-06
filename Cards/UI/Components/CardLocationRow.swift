import SwiftUI

/// One of a card's locations in the edit form: its name and radius, lined up
/// with the form's other icon rows. The radius is in the units chosen in
/// Settings (SET-4).
public struct CardLocationRow: View {
    private let location: CardLocation
    @Environment(\.distanceFormat) private var distanceFormat

    public init(_ location: CardLocation) {
        self.location = location
    }

    public var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .lineLimit(1)
                Text("\(distanceFormat.radius(location.radius)) radius")
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
