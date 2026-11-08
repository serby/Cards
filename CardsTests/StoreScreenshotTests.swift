@testable import Cards
import SwiftUI
import Testing
import UIKit

/// Renders the App Store images: the screenshots, and the universal creative
/// asset, each laid out in its locale's direction. The renders are not part of
/// the normal test run: `make store-screenshots` turns them on with
/// CARDS_STORE_SCREENSHOTS=1. They read and write the repository directly,
/// which a simulator can do.
@MainActor
struct StoreScreenshotTests {
    nonisolated private static let enabled = ProcessInfo.processInfo.environment["CARDS_STORE_SCREENSHOTS"] == "1"
    private static let files = StoreListingFiles.repository

    /// Each device's suffix and the pixel size App Store Connect takes for it.
    private static let devices: [(suffix: String, size: CGSize)] = [
        ("", CGSize(width: 1_320, height: 2_868)),
        ("_iPad", CGSize(width: 2_064, height: 2_752)),
        ("_Duo", CGSize(width: 1_398, height: 2_034))
    ]

    @Test(.enabled(if: enabled))
    func renderStoreScreenshots() throws {
        let locales = try Self.files.locales()
        #expect(!locales.isEmpty)
        for locale in locales {
            let folder = Self.files.store.appending(path: locale)
            let direction = LayoutDirection(storeLocale: locale)
            let captions = try JSONDecoder().decode(
                [StoreScreenshotCaption].self,
                from: Data(contentsOf: folder.appending(path: "captions.json"))
            )
            for caption in captions {
                for device in Self.devices {
                    let name = "\(caption.screen)\(device.suffix)"
                    let image = try #require(Self.files.capture(name, locale: locale), "Missing screenshots/\(locale)/\(name).png")
                    let view = StoreScreenshot(
                        title: caption.title,
                        subtitle: caption.subtitle,
                        color: .stored(caption.color),
                        screenshot: image,
                        layout: caption.layout,
                        canvas: device.size
                    )
                    let png = try render(view.environment(\.layoutDirection, direction), size: device.size)
                    try png.write(to: folder.appending(path: "\(caption.file)\(device.suffix).png"))
                }
            }
        }
    }

    /// One universal creative asset for each locale with a creative-asset.json.
    @Test(.enabled(if: enabled))
    func renderCreativeAssets() throws {
        for locale in try Self.files.locales() {
            guard let entry = try Self.files.creativeAsset(locale) else { continue }
            let image = try #require(Self.files.capture(entry.screen, locale: locale), "Missing screenshots/\(locale)/\(entry.screen).png")
            let view = StoreCreativeAsset(title: entry.title, color: .stored(entry.color), screenshot: image)
                .environment(\.layoutDirection, LayoutDirection(storeLocale: locale))
            let png = try render(view, size: StoreCreativeAsset.canvas)
            try png.write(to: Self.files.store.appending(path: "\(locale)/\(entry.file).png"))
        }
    }

    /// Arabic's images are laid out right to left, as it reads, and every other
    /// store locale's left to right.
    @Test(arguments: [
        ("ar-SA", LayoutDirection.rightToLeft),
        ("fr-FR", LayoutDirection.leftToRight),
        ("en-GB", LayoutDirection.leftToRight),
        ("ja", LayoutDirection.leftToRight)
    ])
    func storeLocalesAreLaidOutInTheirLanguagesDirection(_ locale: String, _ direction: LayoutDirection) {
        #expect(LayoutDirection(storeLocale: locale) == direction)
    }

    private func render(_ view: some View, size: CGSize) throws -> Data {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        // App Store Connect refuses images with an alpha channel.
        renderer.isOpaque = true
        let rendered = try #require(renderer.uiImage)
        #expect(rendered.size == size)
        return try #require(rendered.pngData())
    }
}
