import SwiftUI

#Preview("Grid") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(CardSummary.samples) { card in
                CardTileView(card: card) {}
            }
        }
        .padding()
    }
}

#Preview("Drop target") {
    CardTileView(card: CardSummary.samples[0], isDropTarget: true) {}
        .frame(width: 180)
        .padding()
}
