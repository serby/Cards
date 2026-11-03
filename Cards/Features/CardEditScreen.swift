import SwiftUI

public struct CardEditScreen: View {
    private let cardItem: CardItem
    private let navigationManager: NavigationManager?
    private let onSave: ((CardItem) -> Void)?
    @Environment(LocationService.self) private var locationService
    @Environment(\.accessibilityAnnouncer) private var announcer

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

    /// What VoiceOver says after a scan, with the code spelled out character
    /// by character, as everywhere else.
    static func scanAnnouncement(code: String, type: BarcodeType?) -> AttributedString {
        var message = if let type {
            AttributedString(
                localized: "Scanned \(String(localized: type.displayName)) code \(code)",
                comment: "VoiceOver announcement after the camera reads a barcode. The arguments are its format, such as EAN-13, then the code."
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
