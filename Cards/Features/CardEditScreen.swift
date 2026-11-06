import SwiftData
import SwiftUI

public struct CardEditScreen: View {
    private let cardItem: CardItem
    private let navigationManager: NavigationManager?
    private let onSave: ((CardItem) -> Void)?
    @Environment(LocationService.self) private var locationService
    @Query private var cards: [CardItem]
    @Environment(\.postcodeLookup) private var postcodeLookup
    @AppStorage(ArrivalPlan.enabledKey) private var arrivalNotifications = true

    @State private var draft: CardDraft
    @State private var scannedCode: String?
    @State private var scannedBarcodeType: BarcodeType?

    private var isNewCard: Bool { onSave != nil }

    public init(
        cardItem: CardItem,
        navigationManager: NavigationManager? = nil,
        onSave: ((CardItem) -> Void)? = nil
    ) {
        self.cardItem = cardItem
        self.navigationManager = navigationManager
        self.onSave = onSave
        _draft = State(
            initialValue: CardDraft(
                name: cardItem.name,
                code: cardItem.code,
                barcodeType: cardItem.getBarcodeType(),
                color: cardItem.getColor(),
                locations: cardItem.locations,
                notifiesOnArrival: cardItem.notifiesOnArrival,
                symbol: cardItem.symbol
            )
        )
    }

    public var body: some View {
        form
            .onChange(of: scannedCode) { _, newCode in
                if let code = newCode {
                    draft.code = code
                }
            }
            .onChange(of: scannedBarcodeType) { _, newType in
                if let type = newType {
                    draft.barcodeType = type
                }
            }
    }

    @ViewBuilder
    private var form: some View {
        if isNewCard {
            CardEditView(
                draft: $draft,
                actions: actions,
                mapCentre: locationService.current?.coordinate,
                takenCodes: takenCodes,
                arrivalNotificationsEnabled: arrivalNotifications,
                scanner: {
                    ScannerOverlayView(scannedCode: $scannedCode, barcodeType: $scannedBarcodeType)
                }
            )
        } else {
            CardEditView(
                draft: $draft,
                actions: actions,
                autofocusesName: true,
                mapCentre: locationService.current?.coordinate,
                takenCodes: takenCodes,
                arrivalNotificationsEnabled: arrivalNotifications
            )
        }
    }

    private var actions: CardEditActions {
        CardEditActions(
            save: save,
            requestLocationAccess: locationService.requestAccess,
            findPlace: postcodeLookup.find
        )
    }

    /// Codes every other card uses. A new card is not in the store yet, so it is never among them.
    private var takenCodes: Set<String> {
        Set(cards.filter { $0 !== cardItem }.map(\.code))
    }

    private func save() {
        guard draft.canSave(takenCodes: takenCodes) else { return }
        cardItem.name = draft.trimmedName
        cardItem.code = draft.trimmedCode
        cardItem.type = draft.barcodeType.rawValue
        cardItem.color = draft.color.rawValue
        cardItem.locations = draft.locations
        cardItem.notifiesOnArrival = draft.notifiesOnArrival
        cardItem.symbol = draft.symbol

        if let onSave {
            onSave(cardItem)
        } else {
            navigationManager?.navigate(to: .card(cardItem.code))
        }
    }
}

#if DEBUG
#Preview {
    let sampleCardItem = CardItem(
        timestamp: Date(),
        code: "123ABC",
        name: "Westway",
        barcodeType: BarcodeType.code128
    )
    NavigationStack {
        CardEditScreen(cardItem: sampleCardItem, navigationManager: NavigationManager())
    }
    .environment(LocationService())
    .modelContainer(for: CardItem.self, inMemory: true)
}
#endif
