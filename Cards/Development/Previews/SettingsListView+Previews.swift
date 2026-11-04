import SwiftUI

#Preview("With cards") {
    @Previewable @State var boost = true
    NavigationStack {
        SettingsListView(state: .sample, brightnessBoost: $boost)
    }
}

#Preview("Notifications blocked") {
    @Previewable @State var arrivals = true
    NavigationStack {
        SettingsListView(state: .withNotificationsBlocked, brightnessBoost: .constant(true), arrivalNotifications: $arrivals)
    }
}

#Preview("No cards") {
    @Previewable @State var boost = false
    NavigationStack {
        SettingsListView(state: .noCards, brightnessBoost: $boost)
    }
}
