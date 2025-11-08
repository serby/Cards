//
//  PortraitLockedView.swift
//  Cards
//
//  Created by Serby, Paul on 02/02/2025.
//

import SwiftUI

// A custom hosting controller that restricts to portrait orientation.
class PortraitHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
}

// A wrapper to use the custom hosting controller in SwiftUI.
struct PortraitLockedView<Content: View>: UIViewControllerRepresentable {
    let content: Content
    
    func makeUIViewController(context: Context) -> PortraitHostingController<Content> {
        PortraitHostingController(rootView: content)
    }
    
    func updateUIViewController(_ uiViewController: PortraitHostingController<Content>, context: Context) {
        uiViewController.rootView = content
    }
}
