//
//  CameraScannerView.swift
//  Cards
//
//  Created by Serby, Paul on 18/12/2024.
//


import SwiftUI
import AVFoundation

struct CameraScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var barcodeType: BarcodeType?
    
    // Create the UIViewController to display the camera
    func makeUIViewController(context: Context) -> ScannerViewController {
        let scannerVC = ScannerViewController()
        scannerVC.delegate = context.coordinator
        return scannerVC
    }

    // Update the view when state changes
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    // Connect SwiftUI's state to the UIKit delegate
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ScannerViewControllerDelegate {
        var parent: CameraScannerView
        
        init(_ parent: CameraScannerView) {
            self.parent = parent
        }
        
        // This is called when a barcode is scanned
        func didFindScannedCode(code: String, type: AVMetadataObject.ObjectType) {
            parent.scannedCode = code
            parent.barcodeType = BarcodeMapper.mapMetadataObjectTypeToBarcodeType(type)
        }
    }
}
