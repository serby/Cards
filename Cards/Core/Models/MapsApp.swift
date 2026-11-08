import Foundation

/// The app a card's places open in, chosen in Settings > Maps (SET-5). Kept on
/// the device under `DeviceSettings.mapsAppKey`, so the raw values are stored
/// and never change. iOS doesn't tell apps which maps app someone uses, so it
/// is Apple Maps until another is chosen.
public enum MapsApp: String, CaseIterable, Identifiable, Sendable {
    case appleMaps
    /// Google Maps' app when it is installed, or its website when it isn't.
    case googleMaps

    public var id: Self { self }
}
