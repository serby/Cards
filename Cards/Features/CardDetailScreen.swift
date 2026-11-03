import SwiftUI

public struct CardDetailScreen: View {
    @AppStorage("brightnessBoost") private var brightnessBoost = true
    @Environment(LocationService.self) private var locationService
    private let item: CardItem
    private let navigationManager: NavigationManager

    public init(item: CardItem, navigationManager: NavigationManager) {
        self.item = item
        self.navigationManager = navigationManager
    }

    public var body: some View {
        CardDetailView(
            card: CardDetail(
                id: item.code,
                name: item.name,
                code: item.code,
                barcodeType: item.getBarcodeType(),
                timestamp: item.timestamp,
                color: item.getColor(),
                proximity: item.locations.proximity(to: locationService.current)
            ),
            brightnessBoost: $brightnessBoost,
            actions: CardDetailActions(
                editCard: { navigationManager.navigate(to: .editCard(item.code)) }
            )
        )
    }
}

#Preview {
    let item = CardItem(
        timestamp: Date(),
        code: "123ABC",
        name: "Westway",
        barcodeType: BarcodeType.code128
    )
    NavigationStack {
        CardDetailScreen(item: item, navigationManager: NavigationManager())
    }
    .environment(LocationService())
    .modelContainer(for: CardItem.self, inMemory: true)
}
