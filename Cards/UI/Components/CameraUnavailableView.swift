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
                Text(reason == .denied ? "Camera access is off" : "No camera")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)
                Text(reason == .denied ? "Turn it on in Settings to scan a card, or type the code below." : "Type the card's code below.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            if reason == .denied {
                Button("Open Settings", action: openSettings)
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
}
