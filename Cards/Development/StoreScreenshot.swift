import SwiftUI
import UIKit

/// One App Store image: a caption over a card colour's gradient, above a
/// screenshot of the app. `make store-screenshots` renders these from the raw
/// captures in screenshots/<locale>/ and the captions in
/// screenshots/store/<locale>/captions.json (see docs/DEVELOPMENT.md).
struct StoreScreenshot: View {
    /// How the screenshot is shown: a whole screen like a phone, or a band of the
    /// Home Screen, such as the widget's, shown edge to edge.
    enum Layout: String, Decodable {
        case screen
        case band
    }

    let title: String
    let subtitle: String
    let color: CardColor
    let screenshot: UIImage
    let layout: Layout
    /// In pixels; the image is rendered at scale 1.
    let canvas: CGSize

    /// A hundredth of the canvas width, so every device gets the same proportions.
    private var unit: CGFloat { canvas.width / 100 }

    var body: some View {
        VStack(spacing: unit * 6) {
            caption
            switch layout {
            case .screen:
                device
            case .band:
                Spacer(minLength: 0)
                band
                Spacer(minLength: 0)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .top)
        .background(color.cardFill)
        .clipped()
    }

    private var caption: some View {
        VStack(spacing: unit * 2.2) {
            Text(title)
                .font(.system(size: unit * 7.6, weight: .bold))
            Text(subtitle)
                .font(.system(size: unit * 4.4, weight: .medium))
                .opacity(0.92)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(color.ink)
        .padding(.horizontal, unit * 8)
        .padding(.top, unit * 11)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The whole screen, framed like a device, running off the bottom edge.
    private var device: some View {
        StorePhoneFrame(screenshot: screenshot, width: canvas.width * 0.8)
    }

    private var band: some View {
        Image(uiImage: screenshot)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: canvas.width * 0.94)
            .clipShape(.rect(cornerRadius: unit * 5))
            .shadow(color: .black.opacity(0.35), radius: unit * 4, y: unit * 2)
            .accessibilityHidden(true)
    }
}

/// One entry in screenshots/store/<locale>/captions.json.
struct StoreScreenshotCaption: Decodable {
    /// The image's name in screenshots/store/<locale>/, before the device suffix.
    let file: String
    /// The raw capture it shows, in screenshots/<locale>/, before the device suffix.
    let screen: String
    let color: String
    let title: String
    let subtitle: String
    let layout: StoreScreenshot.Layout
}
