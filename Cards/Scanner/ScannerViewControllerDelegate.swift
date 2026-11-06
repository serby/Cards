import AVFoundation
import UIKit

@MainActor
protocol ScannerViewControllerDelegate: AnyObject {
    func didFindScannedCode(code: String, type: AVMetadataObject.ObjectType)
}

/// Hosts the camera's preview layer, starts and stops the camera as the
/// scanner appears and disappears, and hands on the first code it reads.
/// The camera itself is `ScannerModel`'s `CameraSession`.
final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: (any ScannerViewControllerDelegate)?
    private let scanner: ScannerModel
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var laidOutBounds: CGRect = .zero

    init(scanner: ScannerModel) {
        self.scanner = scanner
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ScannerViewController is only made in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let preview = AVCaptureVideoPreviewLayer(session: scanner.camera.session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview
        scanner.attach(preview)
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(handlePinch)))
    }

    /// Pinch to zoom, starting from wherever the last pinch left off.
    @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
        switch pinch.state {
        case .changed:
            scanner.pinch(pinch.scale)
        case .ended, .cancelled, .failed:
            scanner.endPinch()
        default:
            break
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
        if view.bounds != laidOutBounds {
            laidOutBounds = view.bounds
            scanner.previewDidResize()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scanner.start(reader: self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scanner.stop()
    }

    /// The scanner is leaving the screen for good.
    func shutDown() {
        scanner.stop()
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let scannedCode = readableObject.stringValue else { return }
        let type = readableObject.type
        // The camera's delegate queue is the main queue (`CameraSession.start`).
        MainActor.assumeIsolated {
            // Reads already on their way when the first one stopped the camera don't count.
            guard scanner.isRunning else { return }
            scanner.stop()
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.didFindScannedCode(code: scannedCode, type: type)
        }
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
