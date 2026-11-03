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

    /// The colour's name, which VoiceOver reads for each swatch in the colour picker.
    public var displayName: LocalizedStringResource {
        switch self {
        case .standard:
            LocalizedStringResource(
                "Default",
                comment: "Card colour name read by VoiceOver in the colour picker: the plain grey card that follows light and dark mode."
            )
        case .red:
            LocalizedStringResource("Red", comment: "Card colour name read by VoiceOver in the colour picker.")
        case .orange:
            LocalizedStringResource("Orange", comment: "Card colour name read by VoiceOver in the colour picker.")
        case .yellow:
            LocalizedStringResource("Yellow", comment: "Card colour name read by VoiceOver in the colour picker.")
        case .green:
            LocalizedStringResource("Green", comment: "Card colour name read by VoiceOver in the colour picker.")
        case .teal:
            LocalizedStringResource("Teal", comment: "Card colour name read by VoiceOver in the colour picker: a dark blue-green.")
        case .blue:
            LocalizedStringResource("Blue", comment: "Card colour name read by VoiceOver in the colour picker.")
        case .indigo:
            LocalizedStringResource("Indigo", comment: "Card colour name read by VoiceOver in the colour picker: a deep violet-blue.")
        case .purple:
            LocalizedStringResource("Purple", comment: "Card colour name read by VoiceOver in the colour picker.")
        case .pink:
            LocalizedStringResource("Pink", comment: "Card colour name read by VoiceOver in the colour picker: a deep raspberry pink.")
        case .brown:
            LocalizedStringResource("Brown", comment: "Card colour name read by VoiceOver in the colour picker.")
        case .graphite:
            LocalizedStringResource("Graphite", comment: "Card colour name read by VoiceOver in the colour picker: a dark blue-grey.")
        }
    }
}
