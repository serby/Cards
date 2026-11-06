@testable import Cards
import SwiftUI
import Testing
import UIKit

/// Renders the App Store images. Not part of the normal test run: `make
/// store-screenshots` turns it on with CARDS_STORE_SCREENSHOTS=1. It reads and
/// writes the repository directly, which a simulator can do.
@MainActor
struct StoreScreenshotTests {
    nonisolated private static let enabled = ProcessInfo.processInfo.environment["CARDS_STORE_SCREENSHOTS"] == "1"
    private static let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    /// Each device's suffix and the pixel size App Store Connect takes for it.
    private static let devices: [(suffix: String, size: CGSize)] = [
        ("", CGSize(width: 1_320, height: 2_868)),
        ("_iPad", CGSize(width: 2_064, height: 2_752)),
        ("_Duo", CGSize(width: 1_398, height: 2_034))
    ]

    @Test(.enabled(if: enabled))
    func renderStoreScreenshots() throws {
        let store = Self.root.appending(path: "screenshots/store")
        let locales = try FileManager.default.contentsOfDirectory(atPath: store.path()).filter { !$0.hasPrefix(".") }
        #expect(!locales.isEmpty)
        for locale in locales.sorted() {
            let folder = store.appending(path: locale)
            let captions = try JSONDecoder().decode(
                [StoreScreenshotCaption].self,
                from: Data(contentsOf: folder.appending(path: "captions.json"))
            )
            for caption in captions {
                for device in Self.devices {
                    let source = Self.root.appending(path: "screenshots/\(locale)/\(caption.screen)\(device.suffix).png")
                    let image = try #require(UIImage(contentsOfFile: source.path()), "Missing \(source.path())")
                    let png = try render(caption, image: image, size: device.size)
                    try png.write(to: folder.appending(path: "\(caption.file)\(device.suffix).png"))
                }
            }
        }
    }

    private func render(_ caption: StoreScreenshotCaption, image: UIImage, size: CGSize) throws -> Data {
        let view = StoreScreenshot(
            title: caption.title,
            subtitle: caption.subtitle,
            color: .stored(caption.color),
            screenshot: image,
            layout: caption.layout,
            canvas: size
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        // App Store Connect refuses images with an alpha channel.
        renderer.isOpaque = true
        let rendered = try #require(renderer.uiImage)
        #expect(rendered.size == size)
        return try #require(rendered.pngData())
    }
}
