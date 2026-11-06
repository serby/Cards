import SwiftData
import SwiftUI

#Preview {
    NavigationStack {
        CardListScreen()
            .environment(NavigationManager())
            .environment(LocationService())
            .environment(ArrivalScheduler(notifications: .silent))
    }
    .modelContainer(for: CardItem.self, inMemory: true)
}
