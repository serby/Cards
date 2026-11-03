import SwiftUI

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ProximityLabel(CardProximity(placeName: "Westway", distance: 0))
        ProximityLabel(CardProximity(placeName: "Westway", distance: 0), showsPlace: true)
        ProximityLabel(CardProximity(placeName: "Westway", distance: 350))
        ProximityLabel(CardProximity(placeName: "Westway", distance: 4_200), showsPlace: true)
    }
}
