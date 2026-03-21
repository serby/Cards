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

public struct ScannerOverlayView: View {
    @Binding var scannedCode: String?
    @Binding var barcodeType: BarcodeType?

    public init(scannedCode: Binding<String?>, barcodeType: Binding<BarcodeType?>) {
        _scannedCode = scannedCode
        _barcodeType = barcodeType
    }

    public var body: some View {
        CameraScannerView(scannedCode: $scannedCode, barcodeType: $barcodeType)
            .overlay {
                Rectangle()
                    .fill(Color.red.opacity(0.8))
                    .frame(height: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("scannerView")
            .accessibilityLabel("Barcode scanner")
    }
}
