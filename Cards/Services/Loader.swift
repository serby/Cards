//
//  Loader.swift
//  Cards
//
//  Created by Serby, Paul on 08/11/2025.
//
#if DEBUG
import MBProgressHUD
import UIKit
class Loader {
    @MainActor
    static func load() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }
        
        let hud = MBProgressHUD.showAdded(to: window, animated: true)
        hud.graceTime = 2.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            hud.hide(animated: true)
        }
    }
}
#endif // DEBUG
