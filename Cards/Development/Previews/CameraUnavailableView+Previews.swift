import SwiftUI

#Preview("Access off") {
    CameraUnavailableView(reason: .denied)
        .frame(height: 250)
        .padding()
}

#Preview("No camera") {
    CameraUnavailableView(reason: .unavailable)
        .frame(height: 250)
        .padding()
}
