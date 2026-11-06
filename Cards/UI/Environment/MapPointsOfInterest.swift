import SwiftUI

public extension EnvironmentValues {
    /// Whether maps show Apple Maps' points of interest, which name real
    /// businesses. On, as they help find a place; the App Store screenshots
    /// turn them off, because no real brand belongs in them (docs/LANGUAGE.md).
    @Entry var mapShowsPointsOfInterest = true
}
