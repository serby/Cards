import AVFoundation
import UIKit

public protocol ScannerViewControllerDelegate: AnyObject {
    func didFindScannedCode(code: String, type: AVMetadataObject.ObjectType)
}

public class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

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
            print("Unable to access the camera")
            return
        }

        videoDevice = videoCaptureDevice
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(handlePinch)))

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                print("Unable to add input to capture session")
                return
            }
        } catch {
            print("Failed to create AVCaptureDeviceInput: \(error)")
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
            print("Unable to add metadata output")
            return
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview
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
        if captureSession?.isRunning == false {
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
