import Foundation

/// A card reduced to what a list row needs to draw itself.
public struct CardSummary: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let color: CardColor
    /// Distance to the nearest location, when the card has any and the user's
    /// location is known.
    public let proximity: CardProximity?

    public init(id: String, name: String, color: CardColor = .standard, proximity: CardProximity? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.proximity = proximity
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

    public init(
        id: String,
        name: String,
        code: String,
        barcodeType: BarcodeType,
        timestamp: Date,
        color: CardColor = .standard,
        proximity: CardProximity? = nil
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.barcodeType = barcodeType
        self.timestamp = timestamp
        self.color = color
        self.proximity = proximity
    }
}

/// The editable form fields, owned by the caller and committed on save.
public struct CardDraft: Hashable, Sendable {
    public var name: String
    public var code: String
    public var barcodeType: BarcodeType
    public var color: CardColor
    public var locations: [CardLocation]

    public init(
        name: String = "",
        code: String = "",
        barcodeType: BarcodeType = .code128,
        color: CardColor = .standard,
        locations: [CardLocation] = []
    ) {
        self.name = name
        self.code = code
        self.barcodeType = barcodeType
        self.color = color
        self.locations = locations
    }
}

/// Everything the settings screen displays that it cannot derive itself.
public struct SettingsState: Hashable, Sendable {
    public let appVersion: String?
    public let appBuild: String?
    public let authorName: String
    public let authorURL: URL?
    public let cardCount: Int

    public init(
        appVersion: String?,
        appBuild: String?,
        authorName: String,
        authorURL: URL?,
        cardCount: Int
    ) {
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.authorName = authorName
        self.authorURL = authorURL
        self.cardCount = cardCount
    }
}
