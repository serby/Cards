import AVFoundation

/// The live scanner: the commands its view sends to the camera. The camera's
/// work runs on `CameraSession`'s queue, in the order it was asked for, so a
/// stop can never overtake the start before it.
@MainActor
final class ScannerModel {
    /// Made on first use, so the models SwiftUI makes and throws away as the
    /// form redraws never create a capture session.
    private(set) lazy var camera = CameraSession()

    /// True from the camera starting until it stops, which includes after a read.
    private(set) var isRunning = false
    /// Counts stops, so a start that finishes after a later stop is ignored.
    private var stops = 0

    private weak var preview: AVCaptureVideoPreviewLayer?
    private var zoom: CGFloat = 1
    private var zoomRange: ClosedRange<CGFloat> = 1...1
    private var pinchStartZoom: CGFloat?
    private var pending: Task<Void, Never>?

    /// The layer showing the camera, which converts the view's rects into the camera's.
    func attach(_ layer: AVCaptureVideoPreviewLayer) {
        preview = layer
    }

    func start(reader: some AVCaptureMetadataOutputObjectsDelegate & Sendable) {
        let stopsSoFar = stops
        enqueue { [camera] in
            // A stop asked for while it was starting wins; its own job stops the camera next.
            guard let setup = await camera.start(reader: reader), self.stops == stopsSoFar else { return }
            self.isRunning = true
            self.zoom = setup.zoom
            self.zoomRange = setup.zoomRange
            self.updateRectOfInterest()
        }
    }

    /// Stops the camera, after a read or when the scanner goes away.
    func stop() {
        stops += 1
        isRunning = false
        enqueue { [camera] in await camera.stop() }
    }

    /// The preview changed size, so the part of the picture it shows did too.
    func previewDidResize() {
        guard isRunning else { return }
        updateRectOfInterest()
    }

    /// A pinch, with how far it has spread since it began: 2 is twice as far apart.
    func pinch(_ scale: CGFloat) {
        // Until the camera has started, its zoom range isn't known.
        guard isRunning else { return }
        let start = pinchStartZoom ?? zoom
        pinchStartZoom = start
        let zoom = CameraPlan.pinchZoom(from: start, scale: scale, within: zoomRange)
        self.zoom = zoom
        enqueue { [camera] in await camera.setZoom(zoom) }
    }

    func endPinch() {
        pinchStartZoom = nil
    }

    /// Reads only codes the person can see in the preview, not ones cropped off its top and bottom.
    private func updateRectOfInterest() {
        guard let preview,
              let rect = CameraPlan.rectOfInterest(preview.metadataOutputRectConverted(fromLayerRect: preview.bounds))
        else { return }
        enqueue { [camera] in await camera.setRectOfInterest(rect) }
    }

    private func enqueue(_ job: @escaping @MainActor () async -> Void) {
        let previous = pending
        pending = Task {
            await previous?.value
            await job()
        }
    }
}
