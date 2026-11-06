import AVFoundation
import SwiftUI

/// The camera's live picture, from `ScannerViewController`. What it reads
/// fills in the bindings.
struct CameraScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var barcodeType: BarcodeType?
    let scanner: ScannerModel

    func makeUIViewController(context: Context) -> ScannerViewController {
        let scannerVC = ScannerViewController(scanner: scanner)
        scannerVC.delegate = context.coordinator
        return scannerVC
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIViewController(_ uiViewController: ScannerViewController, coordinator: Coordinator) {
        uiViewController.shutDown()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        var parent: CameraScannerView

        init(_ parent: CameraScannerView) {
            self.parent = parent
        }

        func didFindScannedCode(code: String, type: AVMetadataObject.ObjectType) {
            parent.scannedCode = code
            parent.barcodeType = BarcodeMapper.mapMetadataObjectTypeToBarcodeType(type)
        }
    }
}

public struct ScannerOverlayView: View {
    @Binding var scannedCode: String?
    @Binding var barcodeType: BarcodeType?
    @State private var camera = CameraState.current
    @State private var scanner = ScannerModel()
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
                CameraScannerView(scannedCode: $scannedCode, barcodeType: $barcodeType, scanner: scanner)
                    .overlay {
                        ScannerControlsView(state: scanner.state, actions: scanner.actions)
                    }
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
