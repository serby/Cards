import Foundation

/// When to ask for an App Store rating (PLAT-8): once a version, after a card
/// has been shown on `daysNeeded` different days in that version, on coming
/// back from a card to the list. Pure: the connector feeds it the dates, the
/// calendar and the version, and keeps it on the device under
/// `DeviceSettings.reviewPromptKey`.
public struct ReviewPrompt: Equatable, Sendable {
    /// The calendar days a card must be shown on, in one version, before the
    /// app asks. Three shows that the app has worked at a till more than once,
    /// on separate trips, rather than on the day it was tried.
    public static let daysNeeded = 3
    /// How long the list shows after a card closes before the app asks, so the
    /// prompt never arrives while the card is still sliding away.
    public static let pause = Duration.seconds(1)

    /// The version the counts below belong to. A new version starts them again.
    public private(set) var version: String
    /// The calendar days a card has been shown on in `version`.
    public private(set) var daysShown: Int
    /// When a card was last shown, to tell a new day from the same one.
    public private(set) var lastShown: Date?
    /// Whether the app has asked in `version`.
    public private(set) var asked: Bool

    public init(version: String = "", daysShown: Int = 0, lastShown: Date? = nil, asked: Bool = false) {
        self.version = version
        self.daysShown = daysShown
        self.lastShown = lastShown
        self.asked = asked
    }

    /// Notes that a card was shown at `date` in `version`. A card shown on a
    /// later calendar day than the last one, in `calendar`'s time zone, adds a
    /// day; another on the same day, or at an earlier time after the clock went
    /// back, does not. A new version starts the count again.
    public mutating func recordCardShown(at date: Date, version: String, calendar: Calendar) {
        if version != self.version {
            self = Self(version: version)
        }
        if let lastShown {
            guard date > lastShown, !calendar.isDate(date, inSameDayAs: lastShown) else { return }
        }
        daysShown += 1
        lastShown = date
    }

    /// Whether to ask now, on coming back from a card in `version`.
    public func isDue(in version: String) -> Bool {
        version == self.version && !asked && daysShown >= Self.daysNeeded
    }

    /// Notes that the app asked in `version`, so it does not ask again until
    /// the next version.
    public mutating func recordAsked(in version: String) {
        if version != self.version {
            self = Self(version: version)
        }
        asked = true
    }
}

/// Kept in `UserDefaults` through `@AppStorage` as a small JSON object. A value
/// it cannot read starts the counts again rather than failing.
extension ReviewPrompt: RawRepresentable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            return nil
        }
        self.init(version: stored.version, daysShown: stored.daysShown, lastShown: stored.lastShown, asked: stored.asked)
    }

    public var rawValue: String {
        let encoder = JSONEncoder()
        // The same state always reads the same, whatever order the keys come out in.
        encoder.outputFormatting = .sortedKeys
        let stored = Stored(version: version, daysShown: daysShown, lastShown: lastShown, asked: asked)
        guard let data = try? encoder.encode(stored) else { return "" }
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    /// Field by field. Without this, Swift would compare the raw values, the
    /// standard library's `==` for every `RawRepresentable` type.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.version == rhs.version
            && lhs.daysShown == rhs.daysShown
            && lhs.lastShown == rhs.lastShown
            && lhs.asked == rhs.asked
    }

    /// The stored form. Separate from `ReviewPrompt` because a type that is both
    /// `RawRepresentable` and `Codable` encodes through its raw value, which
    /// would call itself.
    private struct Stored: Codable {
        var version: String
        var daysShown: Int
        var lastShown: Date?
        var asked: Bool
    }
}
