//
//  CardsApp.swift
//  Cards
//
//  Created by Serby, Paul on 18/12/2024.
//

import SwiftData
import SwiftUI

@main
struct CardsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var navigationManager = NavigationManager()
    private let performanceTracker = PerformanceTracker()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([CardItem.self])
        let isTesting = CommandLine.arguments.contains("-uiTesting")
        
        do {
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isTesting)
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("ModelContainer failed: \(error)")
        }
    }()
    
    private var tabView: some View {
        TabView {
            Tab("Cards", systemImage: "barcode") {
                NavigationStack(path: $navigationManager.navigationPath) {
                    CardListView()
                        .environmentObject(navigationManager)
                }
                .onAppear {
                    navigationManager.resetToRoot()
                }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView()
                }
            }
        }.onAppear {
            performanceTracker.recordAppLaunch()
        }.onOpenURL(perform: navigationManager.handleDeepLink)
    }
    
    var body: some Scene {
        WindowGroup {
            tabView
                .conditionalModifier { view in
                    if #available(iOS 26.0, *) {
                        view.tabBarMinimizeBehavior(.onScrollDown)
                    } else {
                        view
                    }
                }
            
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
