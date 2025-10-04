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
    @Published var wasInBackground = false
    static let appLaunchTime = Date() // Capture actual app launch time
    
    func recordStartTime() {
        startTime = Date()
    }
    
    func printAppStartTime(for type: String) {
        guard let startTime = startTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        print("\(type) Time: \(duration) seconds")
    }
    
    func printColdStartTime() {
        let duration = Date().timeIntervalSince(Self.appLaunchTime)
        print("Cold Start Time: \(duration) seconds")
    }
}

@main
struct CardsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var lifecycleTracker = AppLifecycleTracker()
    
    static let trueLaunchTime = Date() // Capture at App struct creation
    
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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Measure cold start from true app launch
                    let duration = Date().timeIntervalSince(Self.trueLaunchTime)
                    print("Cold Start Time: \(duration) seconds")
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                if lifecycleTracker.wasInBackground {
                    lifecycleTracker.printAppStartTime(for: "Warm Start")
                    lifecycleTracker.wasInBackground = false
                }
            case .background:
                lifecycleTracker.wasInBackground = true
            case .inactive:
                if lifecycleTracker.wasInBackground {
                    lifecycleTracker.recordStartTime() // Start timing resume
                }
            default:
                break
            }
        }
    }
}
