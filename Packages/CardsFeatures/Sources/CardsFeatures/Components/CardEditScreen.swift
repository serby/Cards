import CardsCore
import CardsScanner
import CardsUI
import SwiftUI

public struct CardEditScreen: View {
    private let cardItem: CardItem
    private let navigationManager: NavigationManager?
    private let onSave: ((CardItem) -> Void)?

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
                barcodeType: cardItem.getBarcodeType()
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
                actions: CardEditActions(save: save),
                scanner: {
                    ScannerOverlayView(scannedCode: $scannedCode, barcodeType: $scannedBarcodeType)
                }
            )
        } else {
            CardEditView(
                draft: $draft,
                actions: CardEditActions(save: save),
                autofocusesName: true
            )
        }
    }

    private func save() {
        cardItem.name = draft.name
        cardItem.code = draft.code
        cardItem.type = draft.barcodeType.rawValue

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
    .modelContainer(for: CardItem.self, inMemory: true)
}
