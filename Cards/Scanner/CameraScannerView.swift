import AVFoundation
import SwiftUI

public struct CameraScannerView: UIViewControllerRepresentable {
    @Binding public var scannedCode: String?
    @Binding public var barcodeType: BarcodeType?
    @Binding public var availability: CameraAvailability

    public init(
        scannedCode: Binding<String?>,
        barcodeType: Binding<BarcodeType?>,
        availability: Binding<CameraAvailability> = .constant(.unknown)
    ) {
        _scannedCode = scannedCode
        _barcodeType = barcodeType
        _availability = availability
    }

    public func makeUIViewController(context: Context) -> ScannerViewController {
        let scannerVC = ScannerViewController()
        scannerVC.delegate = context.coordinator
        return scannerVC
    }

    public func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        context.coordinator.parent = self
    }

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

        @MainActor public func cameraAvailabilityChanged(_ availability: CameraAvailability) {
            parent.availability = availability
        }
    }
}

public struct ScannerOverlayView: View {
    @Binding var scannedCode: String?
    @Binding var barcodeType: BarcodeType?
    @State private var availability = CameraAvailability.unknown

    public init(scannedCode: Binding<String?>, barcodeType: Binding<BarcodeType?>) {
        _scannedCode = scannedCode
        _barcodeType = barcodeType
    }

    public var body: some View {
        // A stack, not an overlay: an overlay takes the camera's size, so a
        // long message was cut off at the box's fixed 250 pt. In the stack the
        // message can make the box taller, and the camera fills it.
        ZStack {
            CameraScannerView(scannedCode: $scannedCode, barcodeType: $barcodeType, availability: $availability)
            if availability == .denied {
                // Without access the camera view is black, so say why and
                // what to do instead.
                CameraAccessOffMessage()
            } else {
                Rectangle()
                    .fill(Color.red.opacity(0.8))
                    .frame(height: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("scannerView")
            .accessibilityLabel(
                Text("Barcode scanner", comment: "VoiceOver label for the live camera view at the top of the new card form.")
            )
            .modifier(ScannerAccessibility(availability: availability))
    }
}

/// What VoiceOver says about the scanner, which depends on whether the
/// camera is running.
private struct ScannerAccessibility: ViewModifier {
    let availability: CameraAvailability

    func body(content: Content) -> some View {
        switch availability {
        case .unknown, .available:
            content
                .accessibilityHint(
                    Text(
                        "Reads the barcode you point the camera at, and fills in its code",
                        comment: "VoiceOver hint for the live camera view at the top of the new card form."
                    )
                )
                // So VoiceOver users can pinch to zoom, as touches go straight
                // to the camera view.
                .accessibilityAddTraits(.allowsDirectInteraction)
        case .denied:
            content.accessibilityValue(
                Text(
                    "Camera access is off. Type the code below, or allow camera access in Settings.",
                    comment: "Shown over the black camera view at the top of the new card form when the app may not use the camera."
                )
            )
        case .unavailable:
            content.accessibilityValue(
                Text("Camera not available", comment: "VoiceOver value of the camera view in the new card form when there is no camera to use.")
            )
        }
    }
}
