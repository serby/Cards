//
//  CardsApp.swift
//  Cards
//
//  Created by Serby, Paul on 18/12/2024.
//

import SwiftData
import SwiftUI

class AppLifecycleTracker: ObservableObject {
    @Published var startTime: Date?
    
    func recordStartTime() {
        startTime = Date()
    }
    
    func printAppStartTime(for type: String) {
        guard let startTime = startTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        print("\(type) Time: \(duration) seconds")
    }
}

@main
struct CardsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var lifecycleTracker = AppLifecycleTracker()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CardItem.self
        ])

        let isTesting = CommandLine.arguments.contains("-uiTesting")
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isTesting)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Log Cold Start
        lifecycleTracker.recordStartTime()
        lifecycleTracker.printAppStartTime(for: "Cold Start")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                lifecycleTracker.printAppStartTime(for: "Resume")
            case .background:
                lifecycleTracker.recordStartTime()
            default:
                break
            }
        }
    }
}
