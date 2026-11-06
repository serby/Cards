import AVFoundation
import Observation

/// The live scanner: the state its controls show, and the commands they send
/// to the camera. The camera's work runs on `CameraSession`'s queue, in the
/// order it was asked for, so a stop can never overtake the start before it.
@MainActor
@Observable
final class ScannerModel {
    private(set) var state = ScannerState()

    /// Made on first use, so the models SwiftUI makes and throws away as the
    /// form redraws never create a capture session.
    @ObservationIgnored private(set) lazy var camera = CameraSession()

    /// True from the camera starting until it stops, which includes after a read.
    @ObservationIgnored private(set) var isRunning = false
    /// Counts stops, so a start that finishes after a later stop is ignored.
    @ObservationIgnored private var stops = 0

    @ObservationIgnored private weak var preview: AVCaptureVideoPreviewLayer?
    @ObservationIgnored private var zoom: CGFloat = 1
    @ObservationIgnored private var zoomRange: ClosedRange<CGFloat> = 1...1
    @ObservationIgnored private var pinchStartZoom: CGFloat?
    @ObservationIgnored private var focusMarks = 0
    @ObservationIgnored private var focusMarkTimer: Task<Void, Never>?
    @ObservationIgnored private var pending: Task<Void, Never>?

    var actions: ScannerActions {
        ScannerActions(
            focus: { [weak self] point in self?.focus(at: point) },
            setTorch: { [weak self] isOn in self?.setTorch(isOn) },
            pinch: { [weak self] scale in self?.pinch(scale) },
            endPinch: { [weak self] in self?.endPinch() }
        )
    }

    /// The layer showing the camera, which converts the controls' points into the camera's.
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
            self.state.hasTorch = setup.hasTorch
            self.updateRectOfInterest()
        }
    }

    /// Stops the camera and turns off the torch, after a read or when the scanner goes away.
    func stop() {
        stops += 1
        isRunning = false
        state.torchIsOn = false
        enqueue { [camera] in await camera.stop() }
    }

    /// The preview changed size, so the part of the picture it shows did too.
    func previewDidResize() {
        guard isRunning else { return }
        updateRectOfInterest()
    }

    private func focus(at point: CGPoint) {
        guard isRunning, let preview else { return }
        let devicePoint = CameraPlan.pointOfInterest(preview.captureDevicePointConverted(fromLayerPoint: point))
        showFocusMark(at: point)
        enqueue { [camera] in await camera.focus(at: devicePoint) }
    }

    private func setTorch(_ isOn: Bool) {
        guard isRunning else { return }
        state.torchIsOn = isOn
        enqueue { [camera] in
            let torchIsOn = await camera.setTorch(isOn)
            // A stop asked for meanwhile has turned it off, whatever the camera said.
            self.state.torchIsOn = torchIsOn && self.isRunning
        }
    }

    private func pinch(_ scale: CGFloat) {
        // Until the camera has started, its zoom range isn't known.
        guard isRunning else { return }
        let start = pinchStartZoom ?? zoom
        pinchStartZoom = start
        let zoom = CameraPlan.pinchZoom(from: start, scale: scale, within: zoomRange)
        self.zoom = zoom
        enqueue { [camera] in await camera.setZoom(zoom) }
    }

    private func endPinch() {
        pinchStartZoom = nil
    }

    /// Reads only codes the person can see in the preview, not ones cropped off its top and bottom.
    private func updateRectOfInterest() {
        guard let preview,
              let rect = CameraPlan.rectOfInterest(preview.metadataOutputRectConverted(fromLayerRect: preview.bounds))
        else { return }
        enqueue { [camera] in await camera.setRectOfInterest(rect) }
    }

    private func showFocusMark(at point: CGPoint) {
        focusMarks += 1
        let mark = FocusMark(point: point, id: focusMarks)
        state.focus = mark
        focusMarkTimer?.cancel()
        focusMarkTimer = Task { [weak self] in
            try? await Task.sleep(for: FocusMark.duration)
            guard !Task.isCancelled, let self, self.state.focus == mark else { return }
            self.state.focus = nil
        }
    }

    private func enqueue(_ job: @escaping @MainActor () async -> Void) {
        let previous = pending
        pending = Task {
            await previous?.value
            await job()
        }
    }
}
