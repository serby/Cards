import SwiftUI

/// Stand-in for the camera preview, for stories and previews.
public struct ScannerPlaceholderView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Rectangle().fill(.black)
            Text(verbatim: "Camera preview")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            Rectangle()
                .fill(Color.red.opacity(0.8))
                .frame(height: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("scannerView")
        .accessibilityLabel(Text(verbatim: "Barcode scanner"))
    }
}
