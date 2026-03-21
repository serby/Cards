import AVFoundation
import CardsCore
import UIKit

public protocol ScannerViewControllerDelegate: AnyObject {
    func didFindScannedCode(code: String, type: AVMetadataObject.ObjectType)
}

public class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    public var captureSession: AVCaptureSession?
    public var previewLayer: AVCaptureVideoPreviewLayer?
    public weak var delegate: ScannerViewControllerDelegate?

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black
        let session = AVCaptureSession()
        captureSession = session

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("Unable to access the camera")
            return
        }

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

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if captureSession?.isRunning == false {
            Task { captureSession?.startRunning() }
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }

    nonisolated public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        MainActor.assumeIsolated {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                if let scannedCode = readableObject.stringValue {
                    captureSession?.stopRunning()
                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                    delegate?.didFindScannedCode(code: scannedCode, type: readableObject.type)
                } else {
                    AudioServicesPlaySystemSound(SystemSoundID(1_053))
                }
            }
        }
    }

    public override var prefersStatusBarHidden: Bool { return true }
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .portrait }
}
