import AVFoundation
import CardsCore
import SwiftUI

public struct CameraScannerView: UIViewControllerRepresentable {
    @Binding public var scannedCode: String?
    @Binding public var barcodeType: BarcodeType?

    public init(scannedCode: Binding<String?>, barcodeType: Binding<BarcodeType?>) {
        _scannedCode = scannedCode
        _barcodeType = barcodeType
    }

    public func makeUIViewController(context: Context) -> ScannerViewController {
        let scannerVC = ScannerViewController()
        scannerVC.delegate = context.coordinator
        if let sheet = scannerVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        return scannerVC
    }

    public func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    public static func dismantleUIViewController(_ uiViewController: ScannerViewController, coordinator: Coordinator) {
        uiViewController.captureSession?.stopRunning()
        uiViewController.captureSession = nil
        uiViewController.previewLayer?.removeFromSuperlayer()
        uiViewController.previewLayer = nil
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, ScannerViewControllerDelegate {
        var parent: CameraScannerView

        public init(_ parent: CameraScannerView) {
            self.parent = parent
        }

        @MainActor public func didFindScannedCode(code: String, type: AVMetadataObject.ObjectType) {
            parent.scannedCode = code
            parent.barcodeType = BarcodeMapper.mapMetadataObjectTypeToBarcodeType(type)
        }
    }
}
