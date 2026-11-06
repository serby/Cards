import SwiftUI
import UIKit

/// A screenshot framed like a phone, for the App Store images: a dark bezel whose
/// corners nest round the screen's, and a soft shadow. Every measure is a share
/// of `width`, the screen's width, so the frame looks the same at any size.
struct StorePhoneFrame: View {
    let screenshot: UIImage
    /// The screen's width in pixels; the bezel adds a fiftieth of it on each side.
    let width: CGFloat

    var body: some View {
        let radius = width * 0.105
        let bezel = width * 0.02
        Image(uiImage: screenshot)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width)
            .clipShape(.rect(cornerRadius: radius - bezel))
            .padding(bezel)
            .background(Color(rgb: 0x111111), in: .rect(cornerRadius: radius))
            .shadow(color: .black.opacity(0.35), radius: width * 0.05, y: width * 0.025)
            .accessibilityHidden(true)
    }
}
