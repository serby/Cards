import AVFoundation
import OSLog

/// The scanner's capture session. Configuring, starting and stopping a camera
/// block, so all of it runs on the actor's own serial queue, never the main
/// thread. The decisions it applies are in `CameraPlan`.
actor CameraSession {
    /// What the camera offers once it is running.
    struct Setup: Sendable, Equatable {
        var hasTorch: Bool
        /// The zoom factor it is at now.
        var zoom: CGFloat
        /// The zoom factors pinching can reach.
        var zoomRange: ClosedRange<CGFloat>
    }

    private static let log = Logger(subsystem: "net.serby.Cards", category: "Scanner")

    /// The barcodes the camera reads (BAR-1).
    private static let codeTypes: [AVMetadataObject.ObjectType] = [
        .qr, .ean8, .ean13, .pdf417, .code128, .code39, .code93, .upce, .aztec
    ]

    private let queue = DispatchSerialQueue(label: "net.serby.Cards.camera")

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    /// AVFoundation doesn't mark the session `Sendable`. The preview layer is
    /// given it on the main thread, as Apple's samples do; everything else uses
    /// it only here, on the actor's queue.
    nonisolated(unsafe) let session = AVCaptureSession()

    private let metadataOutput = AVCaptureMetadataOutput()
    private var device: AVCaptureDevice?
    private var zoomRange: ClosedRange<CGFloat> = 1...1
    private var hasConfigured = false
    private var subjectAreaObservation: NotificationObservation?

    /// The camera the scanner uses: the first of the preferred back cameras the
    /// device has, or else whichever camera it has, such as a Mac's. Nil in the
    /// simulator.
    static func preferredDevice() -> AVCaptureDevice? {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: CameraPlan.preferredDeviceTypes,
            mediaType: .video,
            position: .back
        ).devices
        if let type = CameraPlan.deviceType(among: devices.map(\.deviceType)),
           let device = devices.first(where: { $0.deviceType == type }) {
            return device
        }
        return AVCaptureDevice.default(for: .video)
    }

    /// Configures the camera the first time, then starts it, sending what it
    /// reads to `reader` on the main queue. Nil when there is no camera to use.
    func start(reader: some AVCaptureMetadataOutputObjectsDelegate & Sendable) -> Setup? {
        if !hasConfigured {
            hasConfigured = true
            configure()
        }
        guard let device else { return nil }
        metadataOutput.setMetadataObjectsDelegate(reader, queue: .main)
        if !session.isRunning {
            session.startRunning()
        }
        return Setup(hasTorch: device.hasTorch, zoom: device.videoZoomFactor, zoomRange: zoomRange)
    }

    /// Stops the camera, and the torch with it.
    func stop() {
        setTorchMode(.off)
        if session.isRunning {
            session.stopRunning()
        }
    }

    /// Focuses and sets the exposure once at a point from (0, 0) to (1, 1),
    /// then watches for the picture to change so it can go back to continuous
    /// autofocus.
    func focus(at devicePoint: CGPoint) {
        focus(.autoFocus, exposure: .autoExpose, at: devicePoint, monitorsSubjectArea: true)
    }

    /// Turns the torch on or off, and says whether it is on now. It stays off
    /// while the camera is stopped, or when it can't come on, such as when the
    /// phone is too hot.
    func setTorch(_ isOn: Bool) -> Bool {
        guard session.isRunning else { return false }
        setTorchMode(isOn ? .on : .off)
        return device?.torchMode == .on
    }

    func setZoom(_ zoom: CGFloat) {
        guard let device else { return }
        let available = device.minAvailableVideoZoomFactor...device.maxAvailableVideoZoomFactor
        withLockedDevice(device) {
            device.videoZoomFactor = min(max(zoom, available.lowerBound), available.upperBound)
        }
    }

    /// Reads only codes in this part of the picture, in the metadata output's coordinates.
    func setRectOfInterest(_ rect: CGRect) {
        metadataOutput.rectOfInterest = rect
    }

    // MARK: Configuration

    private func configure() {
        guard let device = Self.preferredDevice() else {
            Self.log.error("No camera available")
            return
        }
        guard addInputAndOutput(for: device) else { return }
        self.device = device
        configureFocusAndZoom(device)
        let observer = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.subjectAreaDidChangeNotification,
            object: device,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.subjectAreaDidChange() }
        }
        subjectAreaObservation = NotificationObservation(observer)
    }

    private func addInputAndOutput(for device: AVCaptureDevice) -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                Self.log.error("Unable to add the camera input to the capture session")
                return false
            }
            session.addInput(input)
        } catch {
            Self.log.error("Failed to create the camera input: \(error.localizedDescription, privacy: .public)")
            return false
        }
        guard session.canAddOutput(metadataOutput) else {
            Self.log.error("Unable to add the barcode metadata output")
            return false
        }
        session.addOutput(metadataOutput)
        let available = metadataOutput.availableMetadataObjectTypes
        metadataOutput.metadataObjectTypes = Self.codeTypes.filter(available.contains)
        return true
    }

    /// Continuous autofocus and exposure, autofocus kept to near subjects, and
    /// the zoom `CameraPlan` asks for. Runs after the session is configured, so
    /// the active format, and its field of view, is the one in use.
    private func configureFocusAndZoom(_ device: AVCaptureDevice) {
        let wideLens = device.constituentDevices.first { $0.deviceType == .builtInWideAngleCamera } ?? device
        let wideLensZoom = CameraPlan.wideLensZoomFactor(
            lenses: device.constituentDevices.map(\.deviceType),
            switchOverZoomFactors: device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat($0.doubleValue) }
        )
        zoomRange = CameraPlan.zoomRange(
            wideLensZoom: wideLensZoom,
            minimumAvailable: device.minAvailableVideoZoomFactor,
            maximumAvailable: device.maxAvailableVideoZoomFactor
        )
        // A virtual camera reports the smallest minimum focus distance of its
        // lenses, which on a Pro iPhone is the ultra-wide's macro distance. The
        // scanner starts on the wide lens, so the wide lens's is the one to stay beyond.
        let zoom = CameraPlan.initialZoomFactor(
            minimumFocusDistance: wideLens.minimumFocusDistance,
            fieldOfView: device.activeFormat.videoFieldOfView,
            wideLensZoom: wideLensZoom,
            range: zoomRange
        )
        withLockedDevice(device) {
            // The range restriction takes effect when the focus mode is set, so it comes first.
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.isSubjectAreaChangeMonitoringEnabled = false
            device.videoZoomFactor = zoom
        }
    }

    // MARK: Focus and torch

    /// After a tap, the picture changed enough that the tapped point no longer
    /// means anything: go back to continuous autofocus on the middle.
    private func subjectAreaDidChange() {
        focus(.continuousAutoFocus, exposure: .continuousAutoExposure, at: CGPoint(x: 0.5, y: 0.5), monitorsSubjectArea: false)
    }

    private func focus(
        _ focusMode: AVCaptureDevice.FocusMode,
        exposure exposureMode: AVCaptureDevice.ExposureMode,
        at devicePoint: CGPoint,
        monitorsSubjectArea: Bool
    ) {
        guard let device else { return }
        withLockedDevice(device) {
            // A point of interest takes effect when the mode is set, so it comes first.
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(focusMode) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = focusMode
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(exposureMode) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = exposureMode
            }
            device.isSubjectAreaChangeMonitoringEnabled = monitorsSubjectArea
        }
    }

    private func setTorchMode(_ mode: AVCaptureDevice.TorchMode) {
        guard let device, device.hasTorch, device.torchMode != mode, device.isTorchModeSupported(mode) else { return }
        guard mode == .off || device.isTorchAvailable else { return }
        withLockedDevice(device) {
            device.torchMode = mode
        }
    }

    private func withLockedDevice(_ device: AVCaptureDevice, _ change: () -> Void) {
        do {
            try device.lockForConfiguration()
            change()
            device.unlockForConfiguration()
        } catch {
            // Another app holds the camera; skip this change.
            Self.log.error("Could not lock the camera: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// A notification observer that stops observing when it goes away, with the
/// camera session that holds it.
private final class NotificationObservation {
    private let observer: any NSObjectProtocol

    init(_ observer: any NSObjectProtocol) {
        self.observer = observer
    }

    deinit {
        NotificationCenter.default.removeObserver(observer)
    }
}
