import CoreLocation
import SwiftUI

/// Sets how far round a place counts as there, from 50 m to 1,000 m in steps
/// of 25 m, with the value beside its label (PLACE-3).
public struct RadiusSlider: View {
    @Binding private var radius: CLLocationDistance

    public init(radius: Binding<CLLocationDistance>) {
        _radius = radius
    }

    public var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Radius")
                Spacer()
                Text(radius.radiusText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            Slider(value: $radius, in: CardLocation.radiusRange, step: 25)
                .accessibilityLabel("Radius")
                .accessibilityValue(radius.radiusText)
        }
    }
}

#if DEBUG
#Preview("Default") {
    @Previewable @State var radius = CardLocation.defaultRadius
    RadiusSlider(radius: $radius)
        .padding()
}
#endif
