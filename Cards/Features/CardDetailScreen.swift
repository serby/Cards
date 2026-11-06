import SwiftData
import SwiftUI

public struct CardDetailScreen: View {
    @AppStorage("brightnessBoost") private var brightnessBoost = true
    @Environment(LocationService.self) private var locationService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.placeSearch) private var placeSearch
    @Environment(\.clipboard) private var clipboard
    private let item: CardItem
    private let navigationManager: NavigationManager

    public init(item: CardItem, navigationManager: NavigationManager) {
        self.item = item
        self.navigationManager = navigationManager
    }

    public var body: some View {
        let card = CardDetail(item, near: locationService.current)
        CardDetailView(
            card: card,
            brightnessBoost: $brightnessBoost,
            mapCentre: locationService.current?.coordinate,
            share: share(of: card),
            actions: CardDetailActions(
                editCard: { navigationManager.navigate(to: .editCard(item.code)) },
                addLocation: addLocation,
                requestLocationAccess: locationService.requestAccess,
                placeSearch: placeSearch,
                copyCode: { clipboard.write(item.code) }
            )
        )
        .onAppear(perform: recordView)
    }

    /// Opening a card is what "Last viewed" sorts by (CARD-11). Stored with the
    /// card, so it syncs and exports like its other fields.
    private func recordView() {
        item.lastViewed = .now
        try? modelContext.save()
    }

    /// The link that adds this card to someone else's app, and its picture,
    /// drawn only if the share sheet asks for it.
    private func share(of card: CardDetail) -> CardShare? {
        guard let link = SharedCardLink(card: SharedCard(item)).url else { return nil }
        return CardShare(link: link, image: CardImage(cardName: card.name) { CardShareImage.png(of: card) })
    }

    private func addLocation(_ location: CardLocation) {
        item.locations.append(location)
        try? modelContext.save()
    }
}

#if DEBUG
#Preview {
    let item = CardItem(
        timestamp: Date(),
        code: "123ABC",
        name: "Boulder Barn",
        barcodeType: BarcodeType.code128
    )
    NavigationStack {
        CardDetailScreen(item: item, navigationManager: NavigationManager())
    }
    .environment(LocationService())
    .environment(\.placeSearch, .sample)
    .modelContainer(for: CardItem.self, inMemory: true)
}

#Preview("Several places") {
    let item = CardItem(
        code: "482019375610284",
        name: "Joe's Market",
        barcodeType: .code128,
        color: .blue,
        locations: CardLocation.joesMarket
    )
    NavigationStack {
        CardDetailScreen(item: item, navigationManager: NavigationManager())
    }
    .environment(LocationService(fixedLocation: .sampleHere))
    .modelContainer(for: CardItem.self, inMemory: true)
}
#endif
