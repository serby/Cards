import SwiftUI

/// Stand-in for the camera preview, for stories and previews. With
/// `cameraAccessOff` it shows what the real scanner shows when the app may
/// not use the camera.
public struct ScannerPlaceholderView: View {
    private let cameraAccessOff: Bool

    public init(cameraAccessOff: Bool = false) {
        self.cameraAccessOff = cameraAccessOff
    }

    public var body: some View {
        ZStack {
            Rectangle().fill(.black)
            if cameraAccessOff {
                CameraAccessOffMessage()
            } else {
                Text(verbatim: "Camera preview")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Rectangle()
                    .fill(Color.red.opacity(0.8))
                    .frame(height: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("scannerView")
        .accessibilityLabel(Text(verbatim: "Barcode scanner"))
    }
}
