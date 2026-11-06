import SwiftData
import SwiftUI

public struct CardDetailScreen: View {
    @AppStorage("brightnessBoost") private var brightnessBoost = true
    @Environment(LocationService.self) private var locationService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.postcodeLookup) private var postcodeLookup
    @Environment(\.clipboard) private var clipboard
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
            mapCentre: locationService.current?.coordinate,
            actions: CardDetailActions(
                editCard: { navigationManager.navigate(to: .editCard(item.code)) },
                addLocation: addLocation,
                requestLocationAccess: locationService.requestAccess,
                findPlace: postcodeLookup.find,
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

    private func addLocation(_ location: CardLocation) {
        item.locations.append(location)
        try? modelContext.save()
    }
}
