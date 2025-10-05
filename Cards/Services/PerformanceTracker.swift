//
//  PerformanceTracker.swift
//  Cards
//
//  Created by Serby, Paul on 05/10/2024.
//

import Foundation

protocol PerformanceTracking {
    func recordAppLaunch()
    func recordWarmStart()
    func recordBackgroundTransition()
}

final class PerformanceTracker: PerformanceTracking, ObservableObject {
    private let appLaunchTime = Date()
    private var backgroundTime: Date?
    
    func recordAppLaunch() {
        let duration = Date().timeIntervalSince(appLaunchTime)
        print("Cold Start Time: \(duration) seconds")
    }
    
    func recordWarmStart() {
        guard let backgroundTime = backgroundTime else { return }
        let duration = Date().timeIntervalSince(backgroundTime)
        print("Warm Start Time: \(duration) seconds")
        self.backgroundTime = nil
    }
    
    func recordBackgroundTransition() {
        backgroundTime = Date()
    }
}
