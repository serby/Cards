import SwiftUI

/// Shown where the scanner would be when the camera cannot be used, so the box
/// is never just black. The code can still be typed in below.
public struct CameraUnavailableView: View {
    public enum Reason: Sendable {
        /// Access was refused or is restricted; Settings can turn it on.
        case denied
        /// The device has no camera, such as the simulator.
        case unavailable
    }

    private let reason: Reason
    private let openSettings: () -> Void

    public init(reason: Reason, openSettings: @escaping () -> Void = {}) {
        self.reason = reason
        self.openSettings = openSettings
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Read as one: "No camera, Type the card's code below." The icon is decoration.
            VStack(spacing: 10) {
                Image(systemName: reason == .denied ? "video.slash" : "camera")
                    .font(.title)
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityHidden(true)
                title
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)
                message
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            if reason == .denied {
                Button(action: openSettings) {
                    Text(
                        "Open Settings",
                        comment: "Button where the camera would be in the new card form, when camera access is off: opens the app's page in Settings."
                    )
                }
                .buttonStyle(.bordered)
                .tint(.accent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.rowBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cameraUnavailableView")
    }

    private var title: Text {
        switch reason {
        case .denied:
            Text("Camera access is off", comment: "Heading where the camera would be in the new card form, when the app may not use the camera.")
        case .unavailable:
            Text("No camera", comment: "Heading where the camera would be in the new card form, on a device without a camera.")
        }
    }

    private var message: Text {
        switch reason {
        case .denied:
            Text(
                "Turn it on in Settings to scan a card, or type the code below.",
                comment: "Under “Camera access is off” where the camera would be in the new card form, above the Open Settings button."
            )
        case .unavailable:
            Text(
                "Type the card's code below.",
                comment: "Under “No camera” where the camera would be in the new card form, on a device without a camera."
            )
        }
    }
}

#if DEBUG
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
#endif
