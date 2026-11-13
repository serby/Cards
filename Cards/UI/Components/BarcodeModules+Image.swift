import CoreGraphics

/// Reading a barcode's modules off a drawing, for the Apple Watch (WATCH-1).
/// iPhone only: it draws with RSBarcodes and Core Image, which watchOS lacks.
public extension BarcodeModules {
    /// `code` drawn as `type` by `BarcodeImage`, one module a pixel, so the
    /// watch draws exactly what the phone does; nil when the code cannot be
    /// drawn in that type, as the phone then shows a message instead.
    init?(code: String, type: BarcodeType) {
        guard let image = BarcodeImage.unscaled(code, type: type) else { return nil }
        self.init(darkPixelsOf: image, moduleSize: 1)
    }

    /// The dark and light modules of `image`, a code drawn on white at
    /// `moduleSize` pixels a module, within the smallest rectangle that holds
    /// every dark one: the quiet zone round a code is light, so it is left for
    /// whoever draws the modules to add. A grid whose rows are all the same,
    /// as a strip barcode's are, becomes a single row. Nil for an image with
    /// nothing dark in it.
    init?(darkPixelsOf image: CGImage, moduleSize: Int) {
        let pixels = Self.greys(of: image)
        let (width, height) = (image.width, image.height)
        guard moduleSize > 0, pixels.count == width * height else { return nil }
        let isDark = { (x: Int, y: Int) in pixels[y * width + x] < 128 }

        var left = width, right = -1, top = height, bottom = -1
        for y in 0..<height {
            for x in 0..<width where isDark(x, y) {
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                bottom = max(bottom, y)
            }
        }
        guard right >= left, bottom >= top else { return nil }

        // Each module read at its middle pixel, away from its edges.
        let columns = (right - left + 1) / moduleSize
        let rows = (bottom - top + 1) / moduleSize
        let grid = (0..<rows).map { row in
            (0..<columns).map { column in
                isDark(left + column * moduleSize + moduleSize / 2, top + row * moduleSize + moduleSize / 2)
            }
        }
        guard let first = grid.first else { return nil }
        self.init(dark: grid.allSatisfy { $0 == first } ? [first] : grid)
    }

    /// The image's pixels as greys from 0 (black) to 255 (white), row by row
    /// from the top, over white where it is transparent; none if it cannot be drawn.
    private static func greys(of image: CGImage) -> [UInt8] {
        let (width, height) = (image.width, image.height)
        guard width > 0, height > 0 else { return [] }
        var pixels = [UInt8](repeating: 255, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            let bounds = CGRect(x: 0, y: 0, width: width, height: height)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(bounds)
            context.interpolationQuality = .none
            context.draw(image, in: bounds)
            return true
        }
        return drawn ? pixels : []
    }
}
