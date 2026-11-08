import Foundation

extension MapsApp {
    /// The app's name, as Settings > Maps lists it.
    var title: LocalizedStringResource {
        switch self {
        case .appleMaps:
            LocalizedStringResource(
                "Apple Maps",
                comment: "A choice in Settings > Maps: open places in Apple's Maps app. Use the name Apple gives the app in your language."
            )
        case .googleMaps:
            LocalizedStringResource(
                "Google Maps",
                comment: "A choice in Settings > Maps: open places in Google Maps. Use the name Google gives the app in your language."
            )
        }
    }
}
