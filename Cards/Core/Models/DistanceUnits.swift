import Foundation

/// The units distances are shown in, chosen in Settings > Distances (SET-4).
/// The choice is kept on the device under `DeviceSettings.distanceUnitsKey`, and
/// copied for the widget (`WidgetSettings`), so the raw values are stored and
/// never change.
public enum DistanceUnits: String, CaseIterable, Identifiable, Sendable {
    /// The measurement system set for the device in Language & Region: road
    /// distances as that system writes them, kilometres where it is metric and
    /// miles in the UK and the US.
    case automatic
    /// Kilometres and metres, wherever you are.
    case kilometres
    /// Miles and yards, wherever you are.
    case miles

    public var id: Self { self }

    /// Kilometres or Miles: what Automatic means where `locale` applies.
    public func resolved(for locale: Locale) -> Self {
        guard self == .automatic else { return self }
        switch locale.measurementSystem {
        case .us, .uk:
            return .miles
        default:
            return .kilometres
        }
    }

    /// The choice stored under `raw`, or Automatic for a value this build does
    /// not know, such as one written by a newer build.
    public static func stored(_ raw: String?) -> Self {
        raw.flatMap(Self.init(rawValue:)) ?? .automatic
    }
}
