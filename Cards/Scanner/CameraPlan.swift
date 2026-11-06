import AVFoundation
import CoreGraphics

/// The scanner's camera decisions, as pure functions so tests can check them
/// without a camera, which the simulator does not have: which camera to use,
/// how far to zoom, where to focus and which part of the picture to read.
enum CameraPlan {
    /// The back cameras the scanner looks for, best first, as Apple's AVCam
    /// sample chooses them. A virtual camera built from several lenses switches
    /// to its ultra-wide lens by itself when a card is closer than the wide lens
    /// can focus (macro), so each is preferred over the wide lens alone.
    static let preferredDeviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInTripleCamera,
        .builtInDualWideCamera,
        .builtInDualCamera,
        .builtInWideAngleCamera
    ]

    /// The width of a typical card's barcode, in millimetres. An EAN-13 at its
    /// nominal size is 37.29 mm wide, and most loyalty card barcodes are about that.
    static let typicalCodeWidth: Float = 37

    /// How much of the scanning area's width that barcode should fill. The
    /// scanning area is the whole preview, which shows the camera picture's full
    /// width and crops its top and bottom.
    static let scanningAreaFill: Float = 1

    /// How far the scanner zooms past the wide lens at most. Beyond this the
    /// picture is too soft to read a barcode.
    static let maximumZoom: CGFloat = 8

    /// The first preferred camera among those the device has.
    static func deviceType(among available: [AVCaptureDevice.DeviceType]) -> AVCaptureDevice.DeviceType? {
        preferredDeviceTypes.first(where: available.contains)
    }

    /// The zoom factor at which a camera shows its wide-angle lens. A virtual
    /// camera's zoom factors count from its widest lens, so on one with an
    /// ultra-wide lens the wide lens takes over at the switch-over factor before
    /// it (2 on an iPhone with an ultra-wide). The lenses and the switch-over
    /// factors come in the same order, one factor fewer than lenses. A camera
    /// with no lenses listed is a single lens, at 1.
    static func wideLensZoomFactor(
        lenses: [AVCaptureDevice.DeviceType],
        switchOverZoomFactors: [CGFloat]
    ) -> CGFloat {
        guard let index = lenses.firstIndex(of: .builtInWideAngleCamera),
              index > 0, index <= switchOverZoomFactors.count else { return 1 }
        return switchOverZoomFactors[index - 1]
    }

    /// The zoom factors the scanner uses: from the wide lens, never out to an
    /// ultra-wide whose wide view and lack of focus on older iPhones suit
    /// barcodes badly, up to `maximumZoom` times the wide lens, within what the
    /// camera can do.
    static func zoomRange(
        wideLensZoom: CGFloat,
        minimumAvailable: CGFloat,
        maximumAvailable: CGFloat
    ) -> ClosedRange<CGFloat> {
        let lower = max(minimumAvailable, wideLensZoom)
        let upper = min(maximumAvailable, wideLensZoom * maximumZoom)
        return lower...max(lower, upper)
    }

    /// The distance, in millimetres, at which a code `codeWidth` millimetres
    /// wide fills `fill` of the preview's width, for a camera whose horizontal
    /// field of view is `fieldOfView` degrees.
    ///
    /// This is Apple's formula, from WWDC21 session 10047, "What's new in
    /// camera capture", and its AVCamBarcode sample:
    ///
    ///     let radians = degreesToRadians(fieldOfView / 2)
    ///     let filledCodeSize = minimumCodeSize / previewFillPercentage
    ///     return filledCodeSize / tan(radians)
    static func minimumSubjectDistance(fieldOfView: Float, codeWidth: Float, fill: Float) -> Float {
        let radians = fieldOfView / 2 * .pi / 180
        let filledCodeSize = codeWidth / fill
        return filledCodeSize / tan(radians)
    }

    /// The zoom factor the scanner starts at, so a typical barcode fills the
    /// scanning area while the phone is still beyond the wide lens's minimum
    /// focus distance.
    ///
    /// Apple's rule, from the same session and sample: when a code would have
    /// to come closer than the camera can focus to fill the preview, zoom in by
    /// the ratio of the two distances, so the person holds the phone further
    /// back, where it can focus.
    ///
    ///     if minimumSubjectDistanceForCode < deviceMinimumFocusDistance {
    ///         let zoomFactor = deviceMinimumFocusDistance / minimumSubjectDistanceForCode
    ///
    /// `fieldOfView` is the camera's at zoom factor 1 (its widest lens, on a
    /// virtual camera), so the ratio is a zoom factor in the camera's own terms.
    /// `minimumFocusDistance` is the wide lens's, in millimetres, or -1 when
    /// unknown. The result never starts wider than the wide lens, and stays in
    /// `range`.
    static func initialZoomFactor(
        minimumFocusDistance: Int,
        fieldOfView: Float,
        wideLensZoom: CGFloat,
        range: ClosedRange<CGFloat>,
        codeWidth: Float = typicalCodeWidth,
        fill: Float = scanningAreaFill
    ) -> CGFloat {
        var zoom = wideLensZoom
        if minimumFocusDistance > 0, fieldOfView > 0, fieldOfView < 180 {
            let subjectDistance = minimumSubjectDistance(fieldOfView: fieldOfView, codeWidth: codeWidth, fill: fill)
            let focusDistance = Float(minimumFocusDistance)
            if subjectDistance < focusDistance {
                zoom = max(zoom, CGFloat(focusDistance / subjectDistance))
            }
        }
        return clamp(zoom, to: range)
    }

    /// The zoom factor for a pinch that began at `start` and has spread by
    /// `scale` (2 is twice as far apart), within `range`.
    static func pinchZoom(from start: CGFloat, scale: CGFloat, within range: ClosedRange<CGFloat>) -> CGFloat {
        guard scale.isFinite, scale > 0 else { return clamp(start, to: range) }
        return clamp(start * scale, to: range)
    }

    /// A focus or exposure point of interest, which the camera takes from (0, 0)
    /// to (1, 1). A point converted from a tap at the very edge of the preview
    /// can fall just outside, and one that is not a number goes to the middle.
    static func pointOfInterest(_ point: CGPoint) -> CGPoint {
        CGPoint(x: unitClamp(point.x), y: unitClamp(point.y))
    }

    /// The metadata output's rect of interest for the visible part of the
    /// picture, in the output's coordinates from (0, 0) to (1, 1). Nil when the
    /// conversion has nothing to offer yet, such as before the preview has a
    /// size, so the camera keeps reading the whole picture rather than nothing.
    static func rectOfInterest(_ rect: CGRect) -> CGRect? {
        let values = [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
        guard values.allSatisfy(\.isFinite) else { return nil }
        let visible = rect.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !visible.isNull, !visible.isEmpty else { return nil }
        return visible
    }

    private static func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func unitClamp(_ value: CGFloat) -> CGFloat {
        value.isFinite ? min(max(value, 0), 1) : 0.5
    }
}
