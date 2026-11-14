import Foundation

/// Something the app did, as it is counted with Share Usage Data on (PLAT-15)
/// and kept as a breadcrumb with Share Diagnostics on (PLAT-14). Each is a
/// name and a few fixed values, so none can carry a card's name, code, notes,
/// colour, icon or places, where you are, or anything typed.
public enum AppEvent: Hashable, Sendable {
    /// A screen came up, by the app's own name for it.
    case screen(AppScreen)
    /// A card was added, and how.
    case cardAdded(CardSource)
    /// A card's screen was opened, and from where.
    case cardOpened(CardEntry)
    /// A card's barcode was shown, with Brightness Boost on or off (BAR-4).
    case barcodeShown(brightnessBoost: Bool)
    /// The cards were exported (DATA-2), as a band of how many.
    case cardsExported(CountBand)
    /// Cards were imported (DATA-3), how, and a band of how many were added.
    case cardsImported(ImportSource, added: CountBand)
    /// A setting changed, and to what.
    case settingChanged(AppSetting, to: String)

    /// The name Google Analytics counts it under, in its snake case.
    public var name: String {
        switch self {
        case .screen:
            "screen_view"
        case .cardAdded:
            "card_added"
        case .cardOpened:
            "card_opened"
        case .barcodeShown:
            "barcode_shown"
        case .cardsExported:
            "cards_exported"
        case .cardsImported:
            "cards_imported"
        case .settingChanged:
            "setting_changed"
        }
    }

    /// Its values, each a fixed word from the app, never from a card.
    public var parameters: [String: String] {
        switch self {
        case let .screen(screen):
            ["screen_name": screen.rawValue, "screen_class": screen.rawValue]
        case let .cardAdded(source):
            ["method": source.rawValue]
        case let .cardOpened(entry):
            ["source": entry.rawValue]
        case let .barcodeShown(brightnessBoost):
            ["brightness_boost": brightnessBoost ? "on" : "off"]
        case let .cardsExported(count):
            ["count": count.rawValue]
        case let .cardsImported(source, added):
            ["method": source.rawValue, "added": added.rawValue]
        case let .settingChanged(setting, value):
            ["setting": setting.rawValue, "value": value]
        }
    }
}

/// The screens, by the names the app counts them under.
public enum AppScreen: String, CaseIterable, Sendable {
    case cards
    case card
    case newCard = "new_card"
    case editCard = "edit_card"
    case sharedCard = "shared_card"
    case settings
}

/// How a card came to be added.
public enum CardSource: String, CaseIterable, Sendable {
    /// From the add form: scanned, read from a photo or file, or typed.
    case form
    /// From a share link (SHARE-3).
    case link
}

/// Where a card's screen was opened from.
public enum CardEntry: String, CaseIterable, Sendable {
    case grid
    /// The card for where you are, above the grid (SET-3).
    case cardWhereYouAre = "card_where_you_are"
    /// A `cards://` link, as the widget opens (WID-3), or a universal link.
    case link
    /// An arrival notification (ARR-2).
    case notification
}

/// How cards were imported.
public enum ImportSource: String, CaseIterable, Sendable {
    case pasted
    case file
    /// A file opened in the app from Files, Mail or AirDrop (DATA-11).
    case openedFile = "opened_file"
}

/// The settings whose changes are counted, by name.
public enum AppSetting: String, CaseIterable, Sendable {
    case brightnessBoost = "brightness_boost"
    case arrivalNotifications = "arrival_notifications"
    case showsCardWhereYouAre = "card_where_you_are"
    case distanceUnits = "distance_units"
    case mapsApp = "maps_app"
    case iCloudSync = "icloud_sync"
    case sharesDiagnostics = "share_diagnostics"
}

/// How many, as a band rather than the number, so a count never singles a
/// person out (PLAT-14).
public enum CountBand: String, CaseIterable, Sendable {
    case none
    case few = "1-5"
    case some = "6-20"
    case many = "21+"

    public init(_ count: Int) {
        self = switch count {
        case ...0:
            .none
        case 1...5:
            .few
        case 6...20:
            .some
        default:
            .many
        }
    }
}

/// How long something took, as Share Diagnostics measures it (PLAT-14).
public enum AppTiming: String, CaseIterable, Sendable {
    /// Opening the cards' store at launch.
    case storeOpen = "store.open"
    /// Building the cards, with their barcodes, to send the watch (WATCH-1).
    case watchSnapshot = "watch.snapshot"
}
