import SwiftUI

public extension EnvironmentValues {
    /// The units chosen in Settings > Distances (SET-4). `CardsApp` sets it from
    /// the stored choice, and the widget from the copy it is given.
    @Entry var distanceUnits = DistanceUnits.automatic

    /// How to write distances here: the chosen units, with the environment's
    /// locale for numbers and for what Automatic means.
    var distanceFormat: DistanceFormat {
        DistanceFormat(units: distanceUnits, locale: locale)
    }
}
