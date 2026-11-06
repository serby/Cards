import PhotosUI
import SwiftData
import SwiftUI

public struct CardEditScreen: View {
    private let cardItem: CardItem
    private let navigationManager: NavigationManager?
    private let onSave: ((CardItem) -> Void)?
    @Environment(LocationService.self) private var locationService
    @Query private var cards: [CardItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.postcodeLookup) private var postcodeLookup
    @AppStorage(ArrivalPlan.enabledKey) private var arrivalNotifications = true
    @Environment(\.fileReader) private var fileReader
    @Environment(\.barcodeImageReader) private var barcodeImageReader

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
                icon: cardItem.icon
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
                barcodeImport: barcodeImport,
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
            findPlace: postcodeLookup.find,
            delete: isNewCard ? nil : { delete() }
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
        cardItem.icon = draft.icon

        if let onSave {
            onSave(cardItem)
        } else {
            navigationManager?.navigate(to: .card(cardItem.code))
        }
    }

    /// Choose Photo and Choose File on the add form (CARD-13).
    private var barcodeImport: BarcodeImportActions {
        let files = fileReader
        let barcodes = barcodeImageReader
        return BarcodeImportActions(
            readPhoto: { item in await Self.readPhoto(item, barcodes: barcodes) },
            readFile: { choice in await Self.readFile(choice, files: files, barcodes: barcodes) }
        )
    }

    /// The barcodes in a photo from the photo picker. iOS hands over only the
    /// photo chosen, so the app needs no access to the photo library.
    static func readPhoto(_ item: PhotosPickerItem, barcodes: BarcodeImageReader) async -> BarcodeReading {
        let data = try? await item.loadTransferable(type: Data.self)
        return await read(data, barcodes: barcodes)
    }

    /// The barcodes in an image or a PDF from the Files picker, which
    /// `FileReader` opens inside its security-scoped access.
    static func readFile(
        _ choice: Result<URL, any Error>,
        files: FileReader,
        barcodes: BarcodeImageReader
    ) async -> BarcodeReading {
        let data = try? files.read(choice.get())
        return await read(data, barcodes: barcodes)
    }

    /// What the barcodes in `data` come to. No data, data that is neither a
    /// picture nor a PDF, or a picture Vision cannot look at, is unreadable.
    static func read(_ data: Data?, barcodes: BarcodeImageReader) async -> BarcodeReading {
        guard let data, let detected = try? await barcodes.read(data) else { return .unreadable }
        return BarcodeReading(detected)
    }

    /// Deletes the card and goes back to the list, past its card screen, which
    /// no longer has a card to show (CARD-6).
    private func delete() {
        modelContext.delete(cardItem)
        CardItem.renumber(cards.filter { $0 !== cardItem })
        try? modelContext.save()
        navigationManager?.resetToRoot()
    }
}

#if DEBUG
#Preview {
    let sampleCardItem = CardItem(
        timestamp: Date(),
        code: "123ABC",
        name: "Boulder Barn",
        barcodeType: BarcodeType.code128
    )
    NavigationStack {
        CardEditScreen(cardItem: sampleCardItem, navigationManager: NavigationManager())
    }
    .environment(LocationService())
    .modelContainer(for: CardItem.self, inMemory: true)
}
#endif
