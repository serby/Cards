//
//  CardsApp.swift
//  Cards
//
//  Created by Serby, Paul on 18/12/2024.
//

import SwiftData
import SwiftUI

#if DEBUG
let isProduction = true
#else
let isProduction = true
#endif

@main
struct CardsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var navigationManager = NavigationManager()
    private let performanceTracker = PerformanceTracker()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([CardItem.self])
        let isTesting = CommandLine.arguments.contains("-uiTesting")
        
        print("🔍 ModelContainer Debug Info:")
        print("  - isTesting: \(isTesting)")
        print("  - isProduction: \(isProduction)")
        print("  - Schema models: \(schema.entities.map { $0.name })")
        
        do {
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isTesting, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("ModelContainer failed: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(navigationManager)
                .onAppear {
                    performanceTracker.recordAppLaunch()
                }
                .onOpenURL(perform: navigationManager.handleDeepLink)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                performanceTracker.recordWarmStart()
            case .inactive:
                performanceTracker.recordForegroundTransition()
            case .background:
                performanceTracker.recordBackgroundTransition()
            @unknown default:
                break
            }
        }
    }
}
