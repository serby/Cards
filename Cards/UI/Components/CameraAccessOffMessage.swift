import SwiftUI

/// Shown over the black camera view at the top of the new card form when the
/// app may not use the camera: why it is black, and what to do instead. White,
/// for the black behind it. It takes the height it needs, so the scanner's box
/// grows past its usual 250 pt for a long translation or a large text size
/// rather than cutting the message off.
public struct CameraAccessOffMessage: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "video.slash")
                .font(.title2)
                .accessibilityHidden(true)
            Text(
                "Camera access is off. Type the code below, or allow camera access in Settings.",
                comment: "Shown over the black camera view at the top of the new card form when the app may not use the camera."
            )
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity)
    }
}
