//
//  PerformanceTracker.swift
//  Cards
//
//  Created by Serby, Paul on 05/10/2024.
//

import Foundation

/// Tracks app performance metrics for cold and warm start times
protocol PerformanceTracking {
    func recordAppLaunch()
    func recordWarmStart()
    func recordBackgroundTransition()
    func recordForegroundTransition()
}

/// Service for measuring app launch and transition performance
final class PerformanceTracker: PerformanceTracking {
    private let appLaunchTime = Date()
    private var foregroundTime: Date?
    
    /// Records cold start time from process creation to first interactive frame
    func recordAppLaunch() {
        let duration = Date().timeIntervalSince(appLaunchTime) * 1_000
        print("Cold Start Time: \(String(format: "%.2f", duration)) ms")
    }
    
    /// Records warm start time from foreground transition to interactive state
    func recordWarmStart() {
        guard let foregroundTime = foregroundTime else { return }
        let duration = Date().timeIntervalSince(foregroundTime) * 1_000
        print("Warm Start Time: \(String(format: "%.2f", duration)) ms")
        self.foregroundTime = nil
    }
    
    /// Called when app transitions to background
    func recordBackgroundTransition() {
        // Background transition doesn't require timing
    }
    
    /// Marks the start of a warm start measurement when app returns to foreground
    func recordForegroundTransition() {
        foregroundTime = Date()
    }
}
