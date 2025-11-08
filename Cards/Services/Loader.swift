//
//  Loader.swift
//  Cards
//
//  Created by Serby, Paul on 08/11/2025.
//
#if DEBUG
import MBProgressHUD
import OSLog
import UIKit

class Loader {
    private static let signpostLog = OSLog(subsystem: "com.amazon.testing.serby.cards", category: "Loader")
    
    @MainActor
    static func load() {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "LoaderDisplay", signpostID: signpostID)
        
        let startTime = Date()
        
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            os_signpost(.end, log: signpostLog, name: "LoaderDisplay", signpostID: signpostID)
            return
        }
        
        os_signpost(.event, log: signpostLog, name: "ShowHUD", signpostID: signpostID)
        let hud = MBProgressHUD(view: window)
        hud.graceTime = 2.0
        window.addSubview(hud)
        hud.show(animated: true)
        
        let hudShowTime = Date().timeIntervalSince(startTime)
        print("⏱️ HUD shown in \(String(format: "%.3f", hudShowTime))s")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            os_signpost(.event, log: signpostLog, name: "HideHUD", signpostID: signpostID)
            hud.hide(animated: true)
            
            let totalTime = Date().timeIntervalSince(startTime)
            print("⏱️ Total loader time: \(String(format: "%.3f", totalTime))s")
            os_signpost(.end, log: signpostLog, name: "LoaderDisplay", signpostID: signpostID)
        }
    }
}
#endif // DEBUG
