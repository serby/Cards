import AVFoundation
import OSLog
import UIKit

public protocol ScannerViewControllerDelegate: AnyObject {
    func didFindScannedCode(code: String, type: AVMetadataObject.ObjectType)
    func cameraAvailabilityChanged(_ availability: CameraAvailability)
}

/// Whether the scanner can show the camera, so the form can say when it
/// cannot instead of showing a silent black box.
public enum CameraAvailability: Sendable, Equatable {
    /// Not known yet: still asking for access or setting up.
    case unknown
    case available
    /// The person turned camera access off for the app, or it is restricted.
    case denied
    /// No camera, or it could not be started (a simulator, a Mac without one).
    case unavailable
}

public class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private static let log = Logger(subsystem: "net.serby.Cards", category: "Scanner")

    public var captureSession: AVCaptureSession?
    public var previewLayer: AVCaptureVideoPreviewLayer?
    public weak var delegate: (any ScannerViewControllerDelegate)?
    private var videoDevice: AVCaptureDevice?
    private var zoomAtPinchStart: CGFloat = 1
    /// Beyond this the image is too soft to read a barcode.
    private let maximumZoom: CGFloat = 8

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black
        let session = AVCaptureSession()
        captureSession = session

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            Self.log.error("No camera available")
            report(.unavailable)
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure(session, with: videoCaptureDevice)
        case .notDetermined:
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    configure(session, with: videoCaptureDevice)
                    startIfVisible()
                } else {
                    report(.denied)
                }
            }
        default:
            report(.denied)
        }
    }

    private func configure(_ session: AVCaptureSession, with videoCaptureDevice: AVCaptureDevice) {
        videoDevice = videoCaptureDevice
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(handlePinch)))

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                Self.log.error("Unable to add the camera input to the capture session")
                report(.unavailable)
                return
            }
        } catch {
            Self.log.error("Failed to create the camera input: \(error.localizedDescription, privacy: .public)")
            report(.unavailable)
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .qr, .ean8, .ean13, .pdf417, .code128, .code39, .code93, .upce, .aztec
            ]
        } else {
            Self.log.error("Unable to add the barcode metadata output")
            report(.unavailable)
            return
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview
        report(.available)
    }

    /// Starts the session once access is granted, if the view has already
    /// appeared and so missed `viewDidAppear`'s start.
    private func startIfVisible() {
        guard view.window != nil, captureSession?.isRunning == false else { return }
        Task { captureSession?.startRunning() }
    }

    /// Told on the next turn of the main actor, as `viewDidLoad` can run while
    /// SwiftUI is still updating the view that hosts this one.
    private func report(_ availability: CameraAvailability) {
        Task { [weak self] in
            self?.delegate?.cameraAvailabilityChanged(availability)
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    /// Pinch to zoom, starting from wherever the last pinch left off.
    @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
        guard let device = videoDevice else { return }
        if pinch.state == .began {
            zoomAtPinchStart = device.videoZoomFactor
        }
        let upperBound = min(device.maxAvailableVideoZoomFactor, maximumZoom)
        let zoom = min(max(zoomAtPinchStart * pinch.scale, device.minAvailableVideoZoomFactor), upperBound)
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = zoom
            device.unlockForConfiguration()
        } catch {
            // Another client holds the device; skip this step of the pinch.
        }
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Only once there is a camera to run; while access is being asked for,
        // startIfVisible() starts it.
        if videoDevice != nil, captureSession?.isRunning == false {
            Task { captureSession?.startRunning() }
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }

    nonisolated public func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let scannedCode = readableObject.stringValue else { return }
        let type = readableObject.type
        MainActor.assumeIsolated {
            captureSession?.stopRunning()
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.didFindScannedCode(code: scannedCode, type: type)
        }
    }

    override public var prefersStatusBarHidden: Bool { return true }
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .portrait }
}
