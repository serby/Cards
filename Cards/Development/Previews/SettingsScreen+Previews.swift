import SwiftData
import SwiftUI

#Preview {
    NavigationStack {
        SettingsScreen()
    }
    .modelContainer(for: CardItem.self, inMemory: true)
}
