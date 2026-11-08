import SwiftUI

public extension EnvironmentValues {
    /// The app a card's places open in, chosen in Settings > Maps (SET-5).
    /// `CardsApp` sets it from the stored choice.
    @Entry var mapsApp = MapsApp.appleMaps
}
