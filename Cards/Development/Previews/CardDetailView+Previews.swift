import SwiftUI

#Preview("Sample") {
    @Previewable @State var boost = true
    NavigationStack {
        CardDetailView(card: .sample, brightnessBoost: $boost)
    }
    .environment(\.screenBrightness, .simulated(BrightnessBox()))
    .environment(\.accessibilityAnnouncer, .silent)
}

#Preview("Invalid code") {
    @Previewable @State var boost = true
    NavigationStack {
        CardDetailView(card: .invalidCode, brightnessBoost: $boost)
    }
    .environment(\.screenBrightness, .simulated(BrightnessBox()))
    .environment(\.accessibilityAnnouncer, .silent)
}
