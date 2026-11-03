import SwiftUI

#Preview("Populated") {
    NavigationStack {
        CardListView(cards: CardSummary.samples)
    }
}

#Preview("Empty") {
    NavigationStack {
        CardListView(cards: [])
    }
}
