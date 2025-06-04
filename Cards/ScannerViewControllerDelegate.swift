//
//  ScannerViewControllerDelegate.swift
//  Cards
//
//  Created by Serby, Paul on 18/12/2024.
//

import AVFoundation
import UIKit

protocol ScannerViewControllerDelegate: AnyObject {
    func didFindScannedCode(code: String, type: AVMetadataObject.ObjectType)
}

class ScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: ScannerViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        
        // Select the video device (back camera)
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("Unable to access the camera")
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                print("Unable to add input to capture session")
                return
            }
        } catch {
            print("Failed to create AVCaptureDeviceInput: \(error)")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .qr,
                .ean8,
                .ean13,
                .pdf417,
                .code128,
                .code39,
                .code93,
                .upce,
                .aztec
            ]
        } else {
            print("Unable to add metadata output")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        Task { [weak self] in
            await MainActor.run {
                guard let self = self else { return }
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    // Handle detected barcodes
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            if let scannedCode = readableObject.stringValue {
                captureSession.stopRunning()
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                delegate?.didFindScannedCode(code: scannedCode, type: readableObject.type)
                dismiss(animated: true)
            } else {
                // Play Ket Error sounds
                AudioServicesPlaySystemSound(SystemSoundID(1_053))
            }
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
