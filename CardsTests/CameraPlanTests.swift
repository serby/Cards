import AVFoundation
@testable import Cards
import CoreGraphics
import Testing

/// The scanner's camera decisions, checked without a camera (BAR-5, BAR-6).
struct CameraPlanTests {
    // MARK: Which camera

    @Test(arguments: [
        ([.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera, .builtInTripleCamera,
          .builtInDualWideCamera, .builtInDualCamera], AVCaptureDevice.DeviceType.builtInTripleCamera),
        ([.builtInWideAngleCamera, .builtInDualWideCamera], .builtInDualWideCamera),
        ([.builtInDualCamera, .builtInWideAngleCamera], .builtInDualCamera),
        ([.builtInWideAngleCamera], .builtInWideAngleCamera)
    ] as [([AVCaptureDevice.DeviceType], AVCaptureDevice.DeviceType)])
    func choosesTheFirstPreferredCamera(available: [AVCaptureDevice.DeviceType], chosen: AVCaptureDevice.DeviceType) {
        #expect(CameraPlan.deviceType(among: available) == chosen)
    }

    @Test func choosesNoCameraWithoutAPreferredOne() {
        #expect(CameraPlan.deviceType(among: []) == nil)
        #expect(CameraPlan.deviceType(among: [.builtInTelephotoCamera, .builtInUltraWideCamera]) == nil)
    }

    // MARK: The wide lens

    @Test func theWideLensTakesOverAfterTheUltraWide() {
        let triple = CameraPlan.wideLensZoomFactor(
            lenses: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            switchOverZoomFactors: [2, 10]
        )
        let dualWide = CameraPlan.wideLensZoomFactor(
            lenses: [.builtInUltraWideCamera, .builtInWideAngleCamera],
            switchOverZoomFactors: [2]
        )
        #expect(triple == 2)
        #expect(dualWide == 2)
    }

    @Test func theWideLensIsAtOneWhenItIsTheWidest() {
        let dual = CameraPlan.wideLensZoomFactor(
            lenses: [.builtInWideAngleCamera, .builtInTelephotoCamera],
            switchOverZoomFactors: [2]
        )
        #expect(dual == 1)
        #expect(CameraPlan.wideLensZoomFactor(lenses: [], switchOverZoomFactors: []) == 1)
        // A malformed list, with too few factors, falls back to 1 rather than crashing.
        #expect(CameraPlan.wideLensZoomFactor(lenses: [.builtInUltraWideCamera, .builtInWideAngleCamera], switchOverZoomFactors: []) == 1)
    }

    @Test func zoomRangeRunsFromTheWideLensToEightTimesIt() {
        #expect(CameraPlan.zoomRange(wideLensZoom: 2, minimumAvailable: 1, maximumAvailable: 123) == 2...16)
        #expect(CameraPlan.zoomRange(wideLensZoom: 1, minimumAvailable: 1, maximumAvailable: 5) == 1...5)
        // A camera held back to less than the wide lens, such as when it is hot, can't zoom at all.
        #expect(CameraPlan.zoomRange(wideLensZoom: 2, minimumAvailable: 1, maximumAvailable: 1.5) == 2...2)
    }

    // MARK: Apple's zoom for a minimum focus distance

    @Test func subjectDistanceIsApplesFormula() {
        // (37 / 1) / tan(35°) for a 70° field of view.
        let distance = CameraPlan.minimumSubjectDistance(fieldOfView: 70, codeWidth: 37, fill: 1)
        #expect(abs(distance - 37 / tan(35 * .pi / 180)) < 0.001)
        #expect(abs(distance - 52.84) < 0.01)
        // Filling half the preview needs twice the code, so twice the distance.
        let half = CameraPlan.minimumSubjectDistance(fieldOfView: 70, codeWidth: 37, fill: 0.5)
        #expect(abs(half - 2 * distance) < 0.001)
    }

    @Test func zoomsInSoTheCodeFillsTheAreaBeyondTheFocusLimit() {
        // A wide lens alone: 120 / 52.84.
        let zoom = CameraPlan.initialZoomFactor(minimumFocusDistance: 120, fieldOfView: 70, wideLensZoom: 1, range: 1...8)
        #expect(abs(zoom - 2.271) < 0.001)
    }

    @Test func zoomsAVirtualCameraInItsOwnTerms() {
        // A triple camera's 106° ultra-wide field of view, and its wide lens's 150 mm limit:
        // 150 / (37 / tan(53°)), past the wide lens's own 2.
        let zoom = CameraPlan.initialZoomFactor(minimumFocusDistance: 150, fieldOfView: 106, wideLensZoom: 2, range: 2...16)
        #expect(abs(zoom - 5.380) < 0.001)
    }

    @Test func neverStartsWiderThanTheWideLens() {
        // Close enough to focus already, so Apple's rule asks for no zoom.
        #expect(CameraPlan.initialZoomFactor(minimumFocusDistance: 30, fieldOfView: 70, wideLensZoom: 1, range: 1...8) == 1)
        // Less than the wide lens's own zoom factor.
        #expect(CameraPlan.initialZoomFactor(minimumFocusDistance: 40, fieldOfView: 106, wideLensZoom: 2, range: 2...16) == 2)
    }

    @Test func startsOnTheWideLensWhenTheFocusLimitIsUnknown() {
        #expect(CameraPlan.initialZoomFactor(minimumFocusDistance: -1, fieldOfView: 106, wideLensZoom: 2, range: 2...16) == 2)
        #expect(CameraPlan.initialZoomFactor(minimumFocusDistance: 150, fieldOfView: 0, wideLensZoom: 1, range: 1...8) == 1)
    }

    @Test func initialZoomStaysWithinTheCamerasRange() {
        #expect(CameraPlan.initialZoomFactor(minimumFocusDistance: 2_000, fieldOfView: 70, wideLensZoom: 1, range: 1...8) == 8)
        #expect(CameraPlan.initialZoomFactor(minimumFocusDistance: 120, fieldOfView: 70, wideLensZoom: 1, range: 1...1.5) == 1.5)
    }

    // MARK: Pinching

    @Test func pinchingZoomsFromWhereItBegan() {
        #expect(CameraPlan.pinchZoom(from: 2, scale: 1.5, within: 2...16) == 3)
        #expect(CameraPlan.pinchZoom(from: 4, scale: 0.5, within: 2...16) == 2)
    }

    @Test func pinchingStaysWithinTheRange() {
        #expect(CameraPlan.pinchZoom(from: 2, scale: 100, within: 2...16) == 16)
        #expect(CameraPlan.pinchZoom(from: 2, scale: 0.1, within: 2...16) == 2)
        #expect(CameraPlan.pinchZoom(from: 3, scale: .nan, within: 2...16) == 3)
    }

    // MARK: Tap to focus

    @Test(arguments: [
        (CGPoint(x: 0.3, y: 0.7), CGPoint(x: 0.3, y: 0.7)),
        (CGPoint(x: -0.01, y: 1.02), CGPoint(x: 0, y: 1)),
        (CGPoint(x: 4, y: -3), CGPoint(x: 1, y: 0)),
        (CGPoint(x: CGFloat.nan, y: CGFloat.infinity), CGPoint(x: 0.5, y: 0.5))
    ])
    func pointOfInterestStaysInTheUnitSquare(point: CGPoint, expected: CGPoint) {
        #expect(CameraPlan.pointOfInterest(point) == expected)
    }

    // MARK: Rect of interest

    @Test func rectOfInterestIsTheVisiblePartOfThePicture() {
        let rect = CGRect(x: 0.25, y: 0, width: 0.5, height: 1)
        #expect(CameraPlan.rectOfInterest(rect) == rect)
        // A conversion that spills past the picture is cut back to it. The
        // values are powers of two, so the comparison is exact.
        #expect(
            CameraPlan.rectOfInterest(CGRect(x: -0.125, y: 0.25, width: 1.25, height: 0.5))
                == CGRect(x: 0, y: 0.25, width: 1, height: 0.5)
        )
    }

    @Test func noRectOfInterestUntilThereIsSomethingToRead() {
        #expect(CameraPlan.rectOfInterest(.zero) == nil)
        #expect(CameraPlan.rectOfInterest(CGRect(x: 2, y: 2, width: 1, height: 1)) == nil)
        #expect(CameraPlan.rectOfInterest(CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1)) == nil)
    }
}
