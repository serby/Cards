import SwiftUI

/// Renders a view to PNG data, so a test can check that two views draw exactly
/// the same pixels: a formatted value against the text it should produce, or
/// a view laid out right to left against the same view left to right.
@MainActor
enum Snapshot {
    static func png(_ view: some View) -> Data? {
        let renderer = ImageRenderer(content: view.padding(4).background(Color.white))
        renderer.scale = 2
        return renderer.uiImage?.pngData()
    }
}
