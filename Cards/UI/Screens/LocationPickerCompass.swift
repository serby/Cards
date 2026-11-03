import SwiftUI

/// Where the location picker's map pin moves the place, through its
/// accessibility actions.
enum Compass: CaseIterable {
    case north, south, east, west

    var actionName: Text {
        switch self {
        case .north:
            Text("Move North", comment: "VoiceOver action on the Add Location map pin: moves the place north by the circle's radius.")
        case .south:
            Text("Move South", comment: "VoiceOver action on the Add Location map pin: moves the place south by the circle's radius.")
        case .east:
            Text("Move East", comment: "VoiceOver action on the Add Location map pin: moves the place east by the circle's radius.")
        case .west:
            Text("Move West", comment: "VoiceOver action on the Add Location map pin: moves the place west by the circle's radius.")
        }
    }

    var announcement: String {
        switch self {
        case .north:
            String(localized: "Moved north", comment: "VoiceOver announcement after the Move North action on the Add Location map pin.")
        case .south:
            String(localized: "Moved south", comment: "VoiceOver announcement after the Move South action on the Add Location map pin.")
        case .east:
            String(localized: "Moved east", comment: "VoiceOver announcement after the Move East action on the Add Location map pin.")
        case .west:
            String(localized: "Moved west", comment: "VoiceOver announcement after the Move West action on the Add Location map pin.")
        }
    }
}
