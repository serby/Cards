import SwiftData
import SwiftUI

#Preview {
    NavigationStack {
        CardListScreen()
            .environment(NavigationManager())
            .environment(LocationService())
    }
    .modelContainer(for: CardItem.self, inMemory: true)
}
