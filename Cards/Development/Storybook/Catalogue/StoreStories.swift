import SwiftUI
import UIKit

/// The App Store images, reviewed here before `make store-screenshots` renders them.
@MainActor
let storeStories: [Story] = [
    creativeAssetStory
]

private enum CreativeAssetKnob {
    static let locale = "Locale"
    static let screen = "Screen"
    static let colour = "Colour"
    static let safeArea = "Safe area"

    /// The phone shows a stand-in until the release capture is taken.
    static let standIn = "Stand-in"
    static let capture = "Raw capture"
    static let fromFile = "As in the file"
}

/// The universal creative asset for each locale, as creative-asset.json in its
/// screenshots/store folder describes it, scaled down to fit. The Locale knob
/// picks the text, the Screen knob a stand-in for the card screen or that
/// locale's committed raw capture, and the Safe area knob outlines the part of
/// the asset every crop shows. It reads the files from the repository, so it
/// works in the simulator and shows a message on a device.
@MainActor
private let creativeAssetStory = Story(
    id: "store-creative-asset",
    title: "StoreCreativeAsset",
    section: "Store",
    knobs: [
        .options(CreativeAssetKnob.locale, creativeAssetLocales, creativeAssetLocales.first ?? ""),
        .options(CreativeAssetKnob.screen, [CreativeAssetKnob.standIn, CreativeAssetKnob.capture], CreativeAssetKnob.standIn),
        .options(CreativeAssetKnob.colour, [CreativeAssetKnob.fromFile] + CardColor.allNames, CreativeAssetKnob.fromFile),
        .toggle(CreativeAssetKnob.safeArea, true)
    ],
    gallery: creativeAssetLocales.map { locale in
        (name: locale, view: AnyView(CreativeAssetPreview(locale: locale, usesCapture: false, color: nil, showsSafeArea: true)))
    }
) { knobs in
    let colour = knobs.option(CreativeAssetKnob.colour)
    return AnyView(
        CreativeAssetPreview(
            locale: knobs.option(CreativeAssetKnob.locale),
            usesCapture: knobs.option(CreativeAssetKnob.screen) == CreativeAssetKnob.capture,
            color: colour == CreativeAssetKnob.fromFile ? nil : .named(colour),
            showsSafeArea: knobs.bool(CreativeAssetKnob.safeArea)
        )
        .padding()
    )
}

/// The locales that have a creative asset, read once when the catalogue is built.
@MainActor
private let creativeAssetLocales: [String] = {
    let files = StoreListingFiles.repository
    return ((try? files.locales()) ?? []).filter { (try? files.creativeAsset($0)) != nil }
}()

/// One locale's asset, scaled to the width it is given.
private struct CreativeAssetPreview: View {
    let locale: String
    let usesCapture: Bool
    /// Overrides the file's colour, to try another.
    let color: CardColor?
    let showsSafeArea: Bool

    var body: some View {
        let files = StoreListingFiles.repository
        if let entry = try? files.creativeAsset(locale) {
            let screenshot = usesCapture ? files.capture(entry.screen, locale: locale) : cardScreenStandIn
            if let screenshot {
                ScaledToWidth(size: StoreCreativeAsset.canvas) {
                    StoreCreativeAsset(
                        title: entry.title,
                        color: color ?? .stored(entry.color),
                        screenshot: screenshot,
                        showsSafeArea: showsSafeArea
                    )
                }
            } else {
                ContentUnavailableView(
                    "No raw capture",
                    systemImage: "photo",
                    description: Text("screenshots/\(locale)/\(entry.screen).png is missing.")
                )
            }
        } else {
            ContentUnavailableView(
                "No creative asset",
                systemImage: "doc.questionmark",
                description: Text("No screenshots/store/\(locale)/creative-asset.json. The Storybook reads it from the Mac, in the simulator.")
            )
        }
    }
}

/// `content`, laid out at `size` and scaled down to the width on offer.
private struct ScaledToWidth<Content: View>: View {
    let size: CGSize
    @ViewBuilder let content: () -> Content

    var body: some View {
        Color.clear
            .aspectRatio(size.width / size.height, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    content()
                        .frame(width: size.width, height: size.height)
                        .scaleEffect(proxy.size.width / size.width, anchor: .topLeading)
                }
            }
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("The creative asset, scaled down")
    }
}

/// A stand-in for the card screen's raw capture, drawn at an iPhone 17 Pro
/// Max's size: Joe's Market's face near the top of a light screen, so the
/// layout can be reviewed before the release capture shows the seeded cards.
@MainActor
private let cardScreenStandIn: UIImage? = {
    let renderer = ImageRenderer(content: CardScreenStandIn())
    renderer.scale = CardScreenStandIn.scale
    renderer.isOpaque = true
    return renderer.uiImage
}()

private struct CardScreenStandIn: View {
    static let scale: CGFloat = 3

    var body: some View {
        VStack {
            CardFaceView(card: .here)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                .padding()
            Spacer(minLength: 0)
        }
        .padding(.top, 110)
        // 1,320 by 2,868 pixels at `scale`.
        .frame(width: 440, height: 956)
        .background(.white)
        .environment(\.colorScheme, .light)
        // BarcodeView draws its bars for the display scale, so draw them for the image's.
        .environment(\.displayScale, Self.scale)
    }
}
