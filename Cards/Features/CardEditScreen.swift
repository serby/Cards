import PhotosUI
import SwiftData
import SwiftUI

public struct CardEditScreen: View {
    private let cardItem: CardItem
    private let navigationManager: NavigationManager?
    private let onSave: ((CardItem) -> Void)?
    @Environment(LocationService.self) private var locationService
    @Environment(\.accessibilityAnnouncer) private var announcer
    @Query private var cards: [CardItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.placeSearch) private var placeSearch
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
        _draft = State(initialValue: CardDraft(cardItem))
    }

    public var body: some View {
        form
            .onChange(of: scannedCode) { _, newCode in
                if let code = newCode {
                    draft.code = code
                    // The scan fills the form silently, and an iPad cannot even
                    // vibrate, so say what was read.
                    announcer.announce(Self.scanAnnouncement(code: code, type: scannedBarcodeType))
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
            placeSearch: placeSearch,
            delete: isNewCard ? nil : { delete() }
        )
    }

    /// What VoiceOver says after a scan, with the code spelled out character
    /// by character, as everywhere else. The format's name comes straight
    /// before the code, with no "code" between them: several names already
    /// end in it ("Scanned QR Code code …").
    static func scanAnnouncement(code: String, type: BarcodeType?) -> AttributedString {
        var message = if let type {
            AttributedString(
                localized: "Scanned \(String(localized: type.displayName)): \(code)",
                comment: """
                    VoiceOver announcement after the camera reads a barcode. The arguments are its format, then the code, \
                    as in “Scanned EAN-13: 5012345678900”. The format's name is already translated and may contain the word code, \
                    as QR Code and Code 128 do, so do not add one.
                    """
            )
        } else {
            AttributedString(
                localized: "Scanned code \(code)",
                comment: "VoiceOver announcement after the camera reads a barcode of a format the app does not name. The argument is the code."
            )
        }
        if let range = message.range(of: code, options: .backwards) {
            message[range].accessibilitySpeechSpellsOutCharacters = true
        }
        return message
    }

    /// Codes every other card uses. A new card is not in the store yet, so it is never among them.
    private var takenCodes: Set<String> {
        Set(cards.filter { $0 !== cardItem }.map(\.code))
    }

    private func save() {
        guard draft.canSave(takenCodes: takenCodes) else { return }
        cardItem.apply(draft)

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
    .environment(\.placeSearch, .sample)
    .modelContainer(for: CardItem.self, inMemory: true)
}
#endif
