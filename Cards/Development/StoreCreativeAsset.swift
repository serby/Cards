import SwiftUI
import UIKit

/// The App Store's universal creative asset, which iOS 27 and iPadOS 27 show as
/// both the product page header and the search result: one short line beside a
/// phone showing a card's barcode, over a card colour's gradient. Both sit in
/// the centre safe area of Apple's template; the phone may run on below it,
/// where only its empty lower part goes. `make store-screenshots` renders it
/// from screenshots/store/<locale>/creative-asset.json and that locale's raw
/// capture (see docs/DEVELOPMENT.md).
struct StoreCreativeAsset: View {
    /// The universal asset's size in pixels: 16:9, PNG, no alpha channel.
    static let canvas = CGSize(width: 5_244, height: 2_950)
    /// The "Art Safe Area" of Apple's universal asset template, in pixels: centred
    /// across, nearer the top than the bottom. Apple asks for the key art inside
    /// it, so that it shows on every device and in every orientation.
    static let safeArea = CGRect(x: 1_921, y: 660, width: 1_402, height: 962)

    let title: String
    let color: CardColor
    /// The iPhone's raw capture of the card screen.
    let screenshot: UIImage
    /// Outlines the safe area, for reviewing the layout in the Storybook. The
    /// rendered asset never shows it.
    var showsSafeArea = false

    private var safe: CGRect { Self.safeArea }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color.cardFill)

            HStack(alignment: .top, spacing: safe.width * 0.05) {
                Text(title)
                    .font(.system(size: safe.height * 0.115, weight: .bold))
                    .foregroundStyle(color.ink)
                    .multilineTextAlignment(.leading)
                    // Longer translations shrink rather than leave the safe area.
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                // Its full height, running on below the safe area: the card face
                // in the top half of the screen stays inside it.
                StorePhoneFrame(screenshot: screenshot, width: safe.height * 0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, safe.height * 0.04)
            }
            // A little room inside the edges, for crops that end right on them.
            .padding(.horizontal, safe.width * 0.025)
            .frame(width: safe.width, height: safe.height, alignment: .top)
            .offset(x: safe.minX, y: safe.minY)

            if showsSafeArea {
                safeAreaOutline
            }
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height)
        .clipped()
    }

    private var safeAreaOutline: some View {
        Rectangle()
            .strokeBorder(Color.yellow, style: StrokeStyle(lineWidth: 10, dash: [48, 28]))
            .overlay(alignment: .bottomLeading) {
                Text("Safe area")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .background(Color.yellow)
            }
            .frame(width: safe.width, height: safe.height)
            .offset(x: safe.minX, y: safe.minY)
            .accessibilityHidden(true)
    }
}

/// screenshots/store/<locale>/creative-asset.json: one locale's universal
/// creative asset. The title is that locale's text, translated like the captions.
struct StoreCreativeAssetEntry: Decodable {
    /// The image's name in screenshots/store/<locale>/, before ".png".
    let file: String
    /// The iPhone raw capture the phone shows, in screenshots/<locale>/, before ".png".
    let screen: String
    /// The card colour whose gradient fills the background.
    let color: String
    /// The one short line beside the phone.
    let title: String
}
