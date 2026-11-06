import AVFoundation
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

    public class Coordinator: NSObject, @preconcurrency ScannerViewControllerDelegate {
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
    @State private var camera = CameraState.current
    @Environment(\.openURL) private var openURL

    /// Whether the camera can be used, asked before the scanner starts so a
    /// refusal shows a message rather than a black box.
    private enum CameraState {
        case undecided
        case ready
        case denied
        case unavailable

        static var current: Self {
            guard AVCaptureDevice.default(for: .video) != nil else { return .unavailable }
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                return .ready
            case .notDetermined:
                return .undecided
            default:
                return .denied
            }
        }
    }

    public init(scannedCode: Binding<String?>, barcodeType: Binding<BarcodeType?>) {
        _scannedCode = scannedCode
        _barcodeType = barcodeType
    }

    public var body: some View {
        Group {
            switch camera {
            case .ready:
                CameraScannerView(scannedCode: $scannedCode, barcodeType: $barcodeType)
                    .overlay {
                        Rectangle()
                            .fill(Color.red.opacity(0.8))
                            .frame(height: 2)
                    }
                    .accessibilityIdentifier("scannerView")
                    .accessibilityLabel("Barcode scanner")
            case .undecided:
                Color.black
                    .task {
                        camera = await AVCaptureDevice.requestAccess(for: .video) ? .ready : .denied
                    }
            case .denied:
                CameraUnavailableView(reason: .denied) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
            case .unavailable:
                CameraUnavailableView(reason: .unavailable)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
