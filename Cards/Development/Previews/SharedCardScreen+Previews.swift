import SwiftData
import SwiftUI

#Preview {
    SharedCardScreen(
        link: SharedCardLink(card: SharedCard(name: "Library", code: "29876543210", color: .teal, symbol: "books.vertical.fill")),
        navigationManager: NavigationManager()
    )
    .modelContainer(for: CardItem.self, inMemory: true)
}
