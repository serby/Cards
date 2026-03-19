import CardsCore
import CardsFeatures
import CardsUI
import SwiftData
import SwiftUI

@main
struct CardsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigationManager = NavigationManager()
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

    @ViewBuilder
    private var tabView: some View {
        TabView {
            Tab("Cards", systemImage: "barcode") {
                let nav = Bindable(navigationManager)
                NavigationStack(path: nav.navigationPath) {
                    CardListView()
                        .environment(navigationManager)
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
        }
        .tint(.accent)
        .background(Color.primaryBackground)
        .onAppear {
            performanceTracker.recordAppLaunch()
        }
        .onOpenURL(perform: navigationManager.handleDeepLink)
        .tabBarMinimizeBehaviorIfAvailable()
    }

    var body: some Scene {
        WindowGroup {
            tabView
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
