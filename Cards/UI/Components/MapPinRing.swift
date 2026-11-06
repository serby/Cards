import SwiftUI

/// The pin in the middle of the location picker's map, and the ring round it
/// that shows a place's radius at the map's scale (PLACE-1, PLACE-3). Drawn
/// over the map in screen space, as changing the map's own content while it
/// moves makes MapKit loop (rule 7).
public struct MapPinRing: View {
    /// The ring's width in points, or nil before the map has reported its scale.
    private let diameter: CGFloat?

    public init(diameter: CGFloat?) {
        self.diameter = diameter
    }

    public var body: some View {
        ZStack {
            if let diameter {
                Circle()
                    .fill(Color.accent.opacity(0.16))
                    .strokeBorder(Color.accent, lineWidth: 2)
                    .frame(width: diameter, height: diameter)
            }
            Image(systemName: "mappin")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.accent)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                // Lift the pin so its point, not its middle, marks the centre.
                .offset(y: -17)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("With ring") {
    MapPinRing(diameter: 180)
}
#endif
