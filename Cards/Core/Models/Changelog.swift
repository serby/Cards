import Foundation

/// One version in the changelog, as the What's New screen shows it.
public struct ChangelogVersion: Hashable, Identifiable, Sendable {
    public let version: String
    /// The day it was released on the App Store; nil while it is being prepared.
    public let date: Date?
    public let changes: [ChangelogChange]

    public var id: String { version }

    public init(version: String, date: Date?, changes: [ChangelogChange]) {
        self.version = version
        self.date = date
        self.changes = changes
    }
}

public struct ChangelogChange: Hashable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case new
        case improved
        case fixed
    }

    public let kind: Kind
    public let text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }
}
