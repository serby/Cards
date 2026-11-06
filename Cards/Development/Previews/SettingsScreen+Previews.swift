import SwiftData
import SwiftUI

#Preview {
    NavigationStack {
        SettingsScreen()
    }
    .environment(ArrivalScheduler(notifications: .silent))
    .modelContainer(for: CardItem.self, inMemory: true)
}
