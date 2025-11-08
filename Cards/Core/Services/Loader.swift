//
//  Loader.swift
//  Cards
//
//  Created by Serby, Paul on 08/11/2025.
//
#if DEBUG
import OSLog
import SwiftUI

@MainActor
@Observable
final class Loader {
    static let shared = Loader()
    private(set) var isLoading = false
    
    private static let signpostLog = OSLog(subsystem: "com.amazon.testing.serby.cards", category: "Loader")
    
    private init() {}
    
    func load() {
        let signpostID = OSSignpostID(log: Self.signpostLog)
        os_signpost(.begin, log: Self.signpostLog, name: "LoaderDisplay", signpostID: signpostID)
        
        let startTime = Date()
        
        os_signpost(.event, log: Self.signpostLog, name: "StartLoading", signpostID: signpostID)
        isLoading = true
        
        let loadStartTime = Date().timeIntervalSince(startTime)
        print("⏱️ Loading started in \(String(format: "%.3f", loadStartTime))s")
        
        Task {
            try? await Task.sleep(for: .seconds(3.0))
            os_signpost(.event, log: Self.signpostLog, name: "StopLoading", signpostID: signpostID)
            isLoading = false
            
            let totalTime = Date().timeIntervalSince(startTime)
            print("⏱️ Total loader time: \(String(format: "%.3f", totalTime))s")
            os_signpost(.end, log: Self.signpostLog, name: "LoaderDisplay", signpostID: signpostID)
        }
    }
}
#endif // DEBUG
