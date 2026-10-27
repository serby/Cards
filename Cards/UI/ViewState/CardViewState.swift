import Foundation

/// A card reduced to what a list row needs to draw itself.
public struct CardSummary: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// A card reduced to what the detail screen needs to draw itself.
public struct CardDetail: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let code: String
    public let barcodeType: BarcodeType
    public let timestamp: Date

    public init(id: String, name: String, code: String, barcodeType: BarcodeType, timestamp: Date) {
        self.id = id
        self.name = name
        self.code = code
        self.barcodeType = barcodeType
        self.timestamp = timestamp
    }
}

/// The editable form fields, owned by the caller and committed on save.
public struct CardDraft: Hashable, Sendable {
    public var name: String
    public var code: String
    public var barcodeType: BarcodeType

    public init(name: String = "", code: String = "", barcodeType: BarcodeType = .code128) {
        self.name = name
        self.code = code
        self.barcodeType = barcodeType
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
