import Foundation

/// The background colour a card is drawn with.
///
/// Cards pick from this fixed palette rather than any colour, so the text drawn
/// on top always stays readable. `CardItem` stores the raw value, and anything it
/// does not recognise (an export from a newer version, a hand-edited file) falls
/// back to `.standard`, the neutral look cards had before colours existed.
public enum CardColor: String, Codable, CaseIterable, Hashable, Sendable {
    case standard
    case red
    case orange
    case yellow
    case green
    case teal
    case blue
    case indigo
    case purple
    case pink
    case brown
    case graphite

    /// The colour stored under `rawValue`, or `.standard` if it is unknown.
    public static func stored(_ rawValue: String?) -> Self {
        rawValue.flatMap(Self.init(rawValue:)) ?? .standard
    }
}
