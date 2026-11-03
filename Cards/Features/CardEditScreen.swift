import SwiftUI

public struct CardEditScreen: View {
    private let cardItem: CardItem
    private let navigationManager: NavigationManager?
    private let onSave: ((CardItem) -> Void)?
    @Environment(LocationService.self) private var locationService

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
                locations: cardItem.locations
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
                scanner: {
                    ScannerOverlayView(scannedCode: $scannedCode, barcodeType: $scannedBarcodeType)
                }
            )
        } else {
            CardEditView(
                draft: $draft,
                actions: actions,
                autofocusesName: true
            )
        }
    }

    private var actions: CardEditActions {
        CardEditActions(
            save: save,
            requestLocationAccess: locationService.requestAccess,
            findPlace: PostcodeLookup.find
        )
    }

    private func save() {
        cardItem.name = draft.name
        cardItem.code = draft.code
        cardItem.type = draft.barcodeType.rawValue
        cardItem.color = draft.color.rawValue
        cardItem.locations = draft.locations

        if let onSave {
            onSave(cardItem)
        } else {
            navigationManager?.navigate(to: .card(cardItem.code))
        }
    }
}

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
