@testable import Cards
import SwiftUI
import Testing
import UIKit

/// Renders the universal creative asset. The App Store screenshots are composed
/// from vector templates by scripts/compose-store-images.ts. Not part of the
/// normal test run: `make store-screenshots` turns it on with
/// CARDS_STORE_SCREENSHOTS=1. It reads and writes the repository directly,
/// which a simulator can do.
@MainActor
struct StoreScreenshotTests {
    nonisolated private static let enabled = ProcessInfo.processInfo.environment["CARDS_STORE_SCREENSHOTS"] == "1"
    private static let files = StoreListingFiles.repository

    /// One universal creative asset for each locale with a creative-asset.json.
    @Test(.enabled(if: enabled))
    func renderCreativeAssets() throws {
        for locale in try Self.files.locales() {
            guard let entry = try Self.files.creativeAsset(locale) else { continue }
            let image = try #require(Self.files.capture(entry.screen, locale: locale), "Missing screenshots/\(locale)/\(entry.screen).png")
            let view = StoreCreativeAsset(title: entry.title, color: .stored(entry.color), screenshot: image)
            let png = try render(view, size: StoreCreativeAsset.canvas)
            try png.write(to: Self.files.store.appending(path: "\(locale)/\(entry.file).png"))
        }
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
