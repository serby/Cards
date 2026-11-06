import Foundation
import PhotosUI
import SwiftUI

/// Callbacks a card list raises. Defaults are no-ops so stories and previews
/// can supply only the ones they care about.
@MainActor
public struct CardListActions {
    public var selectCard: (CardSummary.ID) -> Void
    /// Opens the card's edit form, from the long-press menu.
    public var editCard: (CardSummary.ID) -> Void
    public var addCard: () -> Void
    /// Deletes the card at once.
    public var deleteCard: (CardSummary.ID) -> Void
    /// Moves the first card, in custom order, to where the second one is.
    public var moveCard: (_ card: CardSummary.ID, _ target: CardSummary.ID) -> Void

    public init(
        selectCard: @escaping (CardSummary.ID) -> Void = { _ in },
        editCard: @escaping (CardSummary.ID) -> Void = { _ in },
        addCard: @escaping () -> Void = {},
        deleteCard: @escaping (CardSummary.ID) -> Void = { _ in },
        moveCard: @escaping (_ card: CardSummary.ID, _ target: CardSummary.ID) -> Void = { _, _ in }
    ) {
        self.selectCard = selectCard
        self.editCard = editCard
        self.addCard = addCard
        self.deleteCard = deleteCard
        self.moveCard = moveCard
    }
}

@MainActor
public struct CardDetailActions {
    public var editCard: () -> Void
    /// Saves a place picked on the map as one of the card's locations.
    public var addLocation: (CardLocation) -> Void
    /// Called when the location picker opens, so the map can show where you are.
    public var requestLocationAccess: () -> Void
    /// Finds and names places in the location picker.
    public var placeSearch: PlaceSearch
    /// Puts the card's code on the clipboard.
    public var copyCode: () -> Void

    public init(
        editCard: @escaping () -> Void = {},
        addLocation: @escaping (CardLocation) -> Void = { _ in },
        requestLocationAccess: @escaping () -> Void = {},
        placeSearch: PlaceSearch = .unavailable,
        copyCode: @escaping () -> Void = {}
    ) {
        self.editCard = editCard
        self.addLocation = addLocation
        self.requestLocationAccess = requestLocationAccess
        self.placeSearch = placeSearch
        self.copyCode = copyCode
    }
}

@MainActor
public struct CardEditActions {
    public var save: () -> Void
    /// Called when the location picker opens, so the map can show where you are.
    public var requestLocationAccess: () -> Void
    /// Finds and names places in the location picker.
    public var placeSearch: PlaceSearch
    /// Deletes the card being edited, once the person has confirmed. Nil when
    /// adding a card, which has nothing to delete yet, so the form offers none.
    public var delete: (() -> Void)?

    public init(
        save: @escaping () -> Void = {},
        requestLocationAccess: @escaping () -> Void = {},
        placeSearch: PlaceSearch = .unavailable,
        delete: (() -> Void)? = nil
    ) {
        self.save = save
        self.requestLocationAccess = requestLocationAccess
        self.placeSearch = placeSearch
        self.delete = delete
    }
}

/// What the "Add Card?" sheet raises. Cancel just closes the sheet.
@MainActor
public struct SharedCardActions {
    /// Adds the shared card and opens it.
    public var add: () -> Void
    /// Opens the card already in the app with the shared card's code.
    public var open: () -> Void

    public init(add: @escaping () -> Void = {}, open: @escaping () -> Void = {}) {
        self.add = add
        self.open = open
    }
}

@MainActor
public struct SettingsActions {
    public var exportCards: () -> Void
    public var importCards: (String) -> Void
    /// Imports the file chosen in the Files picker, or reports that none could be.
    public var importFile: (Result<URL, any Error>) -> Void
    public var deleteAllCards: () -> Void
    public var readClipboard: () -> String?
    /// Opens the app's page in the Settings app, where notifications are allowed.
    public var openNotificationSettings: () -> Void

    public init(
        exportCards: @escaping () -> Void = {},
        importCards: @escaping (String) -> Void = { _ in },
        importFile: @escaping (Result<URL, any Error>) -> Void = { _ in },
        deleteAllCards: @escaping () -> Void = {},
        readClipboard: @escaping () -> String? = { nil },
        openNotificationSettings: @escaping () -> Void = {}
    ) {
        self.exportCards = exportCards
        self.importCards = importCards
        self.importFile = importFile
        self.deleteAllCards = deleteAllCards
        self.readClipboard = readClipboard
        self.openNotificationSettings = openNotificationSettings
    }
}

/// What Choose Photo and Choose File raise on the add form: read the chosen
/// photo or file for barcodes (CARD-13). Each takes what its picker gave back.
@MainActor
public struct BarcodeImportActions {
    /// Reads the barcodes in a photo chosen in the photo picker.
    public var readPhoto: (PhotosPickerItem) async -> BarcodeReading
    /// Reads the barcodes in an image or PDF chosen in the Files picker, or
    /// reports that none could be chosen.
    public var readFile: (Result<URL, any Error>) async -> BarcodeReading

    public init(
        readPhoto: @escaping (PhotosPickerItem) async -> BarcodeReading = { _ in .nothing },
        readFile: @escaping (Result<URL, any Error>) async -> BarcodeReading = { _ in .nothing }
    ) {
        self.readPhoto = readPhoto
        self.readFile = readFile
    }
}
