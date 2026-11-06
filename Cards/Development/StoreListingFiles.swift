import Foundation
import UIKit

/// Where the App Store images and their text live in the repository. The
/// renderer and the Storybook both read them from the Mac's disk, which an app
/// in the simulator can; on a device the files are not there.
struct StoreListingFiles {
    /// The repository's root.
    let root: URL

    /// The checkout this was built from, found from this file's path.
    static let repository = Self(
        root: URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    )

    /// screenshots/store, which holds a folder of images and text for each locale.
    var store: URL { root.appending(path: "screenshots/store") }

    /// The locales with a folder in screenshots/store, sorted.
    func locales() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: store.path()).filter { !$0.hasPrefix(".") }.sorted()
    }

    /// The locale's creative asset entry, or nil if it has none.
    func creativeAsset(_ locale: String) throws -> StoreCreativeAssetEntry? {
        let url = store.appending(path: "\(locale)/creative-asset.json")
        guard FileManager.default.fileExists(atPath: url.path()) else { return nil }
        return try JSONDecoder().decode(StoreCreativeAssetEntry.self, from: Data(contentsOf: url))
    }

    /// The raw capture screenshots/<locale>/<name>.png, or nil if it is missing.
    func capture(_ name: String, locale: String) -> UIImage? {
        UIImage(contentsOfFile: root.appending(path: "screenshots/\(locale)/\(name).png").path())
    }
}
