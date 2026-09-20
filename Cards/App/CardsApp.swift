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
        let environment = ProcessInfo.processInfo.environment
        let isTesting = CommandLine.arguments.contains("-uiTesting")
            || environment["CARDS_UI_TESTING"] == "1"
        let seedScreenshots = CommandLine.arguments.contains("-screenshotSeed")
            || environment["CARDS_SCREENSHOT_SEED"] == "1"

        do {
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isTesting)
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            if seedScreenshots {
                let context = container.mainContext
                let seeds: [(String, String, BarcodeType)] = [
                    ("Tesco Clubcard", "634004024987531", .ean13),
                    ("Boots Advantage", "9780201379624", .ean13),
                    ("Costa Coffee", "1234567890128", .ean13),
                    ("Nectar", "9988776655443", .code128),
                    ("Sainsbury's Nectar", "5012345678900", .ean13),
                    ("IKEA Family", "7350053850019", .code128),
                ]
                for (index, seed) in seeds.enumerated() {
                    context.insert(CardItem(code: seed.1, name: seed.0, barcodeType: seed.2, order: index))
                }
                try context.save()
            }
            return container
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
