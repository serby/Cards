import Foundation

/// The background colour a card is drawn with: one of the palette's, or any
/// colour the user picks.
///
/// `CardItem` stores `rawValue`: a palette name such as "blue", or "#RRGGBB" for a
/// custom colour, so custom colours needed no new field and no CloudKit schema
/// change. Anything unrecognised (an export from a newer version, a hand-edited
/// file) falls back to `.standard`, the neutral look cards had before colours
/// existed. Builds before custom colours read "#RRGGBB" that way too.
public enum CardColor: Hashable, Sendable {
    case standard
    case red
    case coral
    case orange
    case yellow
    case lime
    case green
    case olive
    case mint
    case teal
    case sky
    case blue
    case indigo
    case navy
    case lavender
    case purple
    case pink
    case rose
    case maroon
    case brown
    case sand
    case graphite
    case black
    /// Any colour, as sRGB 0xRRGGBB.
    case custom(UInt32)

    /// The colour stored under `rawValue`, or `.standard` if it is unknown.
    public static func stored(_ rawValue: String?) -> Self {
        rawValue.flatMap(Self.init(rawValue:)) ?? .standard
    }

    public var isCustom: Bool {
        if case .custom = self { true } else { false }
    }
}

extension CardColor: CaseIterable {
    /// The palette, in the order the picker shows it: by hue, then the neutrals.
    /// Custom colours are not listed.
    public static let allCases: [Self] = [
        .standard, .red, .coral, .orange, .yellow, .lime, .green, .olive, .mint, .teal, .sky,
        .blue, .indigo, .navy, .lavender, .purple, .pink, .rose, .maroon, .brown, .sand, .graphite, .black
    ]
}

extension CardColor: RawRepresentable {
    public init?(rawValue: String) {
        if let palette = Self.allCases.first(where: { $0.rawValue == rawValue }) {
            self = palette
        } else if let rgb = Self.rgb(hex: rawValue) {
            self = .custom(rgb)
        } else {
            return nil
        }
    }

    /// Spelled out rather than derived from the case names, because these are
    /// stored in every card and must never change.
    public var rawValue: String {
        switch self {
        case .standard:
            "standard"
        case .red:
            "red"
        case .coral:
            "coral"
        case .orange:
            "orange"
        case .yellow:
            "yellow"
        case .lime:
            "lime"
        case .green:
            "green"
        case .olive:
            "olive"
        case .mint:
            "mint"
        case .teal:
            "teal"
        case .sky:
            "sky"
        case .blue:
            "blue"
        case .indigo:
            "indigo"
        case .navy:
            "navy"
        case .lavender:
            "lavender"
        case .purple:
            "purple"
        case .pink:
            "pink"
        case .rose:
            "rose"
        case .maroon:
            "maroon"
        case .brown:
            "brown"
        case .sand:
            "sand"
        case .graphite:
            "graphite"
        case .black:
            "black"
        case .custom(let rgb):
            String(format: "#%06X", rgb & 0xFFFFFF)
        }
    }

    /// 0xRRGGBB from "#RRGGBB", in either case.
    private static func rgb(hex: String) -> UInt32? {
        let digits = hex.dropFirst()
        guard hex.hasPrefix("#"), digits.count == 6, digits.allSatisfy(\.isHexDigit) else { return nil }
        return UInt32(digits, radix: 16)
    }
}

/// Encoded as its raw value, the same string `CardItem` stores, so the widget
/// snapshot reads like the rest of the app's data.
extension CardColor: Codable {
    public init(from decoder: any Decoder) throws {
        self = Self.stored(try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
