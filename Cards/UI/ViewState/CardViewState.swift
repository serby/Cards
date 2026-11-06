import Foundation

/// A card reduced to what a list row needs to draw itself.
public struct CardSummary: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let color: CardColor
    /// Distance to the nearest location, when the card has any and the user's
    /// location is known.
    public let proximity: CardProximity?
    /// The card's SF Symbol, or nil for none.
    public let symbol: String?

    public init(id: String, name: String, color: CardColor = .standard, proximity: CardProximity? = nil, symbol: String? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.proximity = proximity
        self.symbol = symbol
    }
}

/// A card reduced to what the detail screen needs to draw itself.
public struct CardDetail: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let code: String
    public let barcodeType: BarcodeType
    public let timestamp: Date
    public let color: CardColor
    public let proximity: CardProximity?
    /// The card's SF Symbol, or nil for none.
    public let symbol: String?

    public init(
        id: String,
        name: String,
        code: String,
        barcodeType: BarcodeType,
        timestamp: Date,
        color: CardColor = .standard,
        proximity: CardProximity? = nil,
        symbol: String? = nil
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.barcodeType = barcodeType
        self.timestamp = timestamp
        self.color = color
        self.proximity = proximity
        self.symbol = symbol
    }
}

/// The editable form fields, owned by the caller and committed on save.
public struct CardDraft: Hashable, Sendable {
    public var name: String
    public var code: String
    public var barcodeType: BarcodeType
    public var color: CardColor
    public var locations: [CardLocation]
    public var notifiesOnArrival: Bool
    /// The card's SF Symbol, or nil for none.
    public var symbol: String?

    public init(
        name: String = "",
        code: String = "",
        barcodeType: BarcodeType = .code128,
        color: CardColor = .standard,
        locations: [CardLocation] = [],
        notifiesOnArrival: Bool = true,
        symbol: String? = nil
    ) {
        self.name = name
        self.code = code
        self.barcodeType = barcodeType
        self.color = color
        self.locations = locations
        self.notifiesOnArrival = notifiesOnArrival
        self.symbol = symbol
    }
}

public extension CardDraft {
    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedCode: String { code.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Whether another card already uses this code. The code is how a card is
    /// found from links, notifications and the widget, so two cards cannot share one.
    func codeIsTaken(by takenCodes: Set<String>) -> Bool {
        takenCodes.contains(trimmedCode)
    }

    /// A card needs a name and a code of its own.
    func canSave(takenCodes: Set<String>) -> Bool {
        !trimmedName.isEmpty && !trimmedCode.isEmpty && !codeIsTaken(by: takenCodes)
    }
}

/// Everything the settings screen displays that it cannot derive itself.
public struct SettingsState: Hashable, Sendable {
    public let appVersion: String?
    public let appBuild: String?
    public let authorName: String
    public let authorURL: URL?
    public let cardCount: Int
    /// Notifications are switched off for the app in the Settings app.
    public let notificationsBlocked: Bool
    /// Every version and its changes, newest first, for What's New.
    public let changelog: [ChangelogVersion]

    public init(
        appVersion: String?,
        appBuild: String?,
        authorName: String,
        authorURL: URL?,
        cardCount: Int,
        notificationsBlocked: Bool = false,
        changelog: [ChangelogVersion] = []
    ) {
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.authorName = authorName
        self.authorURL = authorURL
        self.cardCount = cardCount
        self.notificationsBlocked = notificationsBlocked
        self.changelog = changelog
    }
}
