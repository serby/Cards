import SwiftUI

#Preview("With cards") {
    @Previewable @State var boost = true
    NavigationStack {
        SettingsListView(state: .sample, brightnessBoost: $boost)
    }
}

#Preview("No cards") {
    @Previewable @State var boost = false
    NavigationStack {
        SettingsListView(state: .noCards, brightnessBoost: $boost)
    }
}
