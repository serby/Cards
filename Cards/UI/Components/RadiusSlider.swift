import CoreLocation
import SwiftUI

/// Sets how far round a place counts as there, with the value beside its label
/// (PLACE-3): from 50 m to 1,000 m in steps of 25 m, or in yards, from 50 yd to
/// 1,100 yd in steps of 25 yd, when distances are in miles (SET-4). The radius
/// stays in metres either way.
public struct RadiusSlider: View {
    @Binding private var radius: CLLocationDistance
    @Environment(\.distanceFormat) private var distanceFormat

    public init(radius: Binding<CLLocationDistance>) {
        _radius = radius
    }

    public var body: some View {
        let scale = distanceFormat.radiusScale
        VStack(spacing: 6) {
            HStack {
                Text("Radius")
                Spacer()
                Text(distanceFormat.radius(radius))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            Slider(
                value: Binding(get: { scale.value(ofMetres: radius) }, set: { radius = scale.metres($0) }),
                in: scale.range,
                step: scale.step
            )
            .accessibilityLabel("Radius")
            .accessibilityValue(distanceFormat.radius(radius, width: .wide))
        }
    }
}

#if DEBUG
#Preview("Default") {
    @Previewable @State var radius = CardLocation.defaultRadius
    RadiusSlider(radius: $radius)
        .padding()
}

#Preview("In yards") {
    @Previewable @State var radius = CardLocation.defaultRadius
    RadiusSlider(radius: $radius)
        .padding()
        .environment(\.distanceUnits, .miles)
}
#endif
