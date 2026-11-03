import MapKit
import SwiftUI

#Preview {
    LocationPickerView(
        initialPosition: .region(CardLocation.previewRegion),
        findPlace: { _ in nil },
        onAdd: { _ in }
    )
}
