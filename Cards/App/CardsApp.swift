import SwiftData
import SwiftUI
import UserNotifications

@main
struct CardsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigationManager: NavigationManager
    @State private var locationService = LocationService()
    private let performanceTracker = PerformanceTracker()
    private let arrivalRouter: ArrivalNotificationRouter

    init() {
        let navigationManager = NavigationManager()
        _navigationManager = State(initialValue: navigationManager)
        // Set before launch finishes so a tap that launched the app is not missed.
        arrivalRouter = ArrivalNotificationRouter { code in
            navigationManager.navigate(to: .card(code))
        }
        UNUserNotificationCenter.current().delegate = arrivalRouter
    }

    /// UI tests drive the shipping UI, so debug-only extras such as the
    /// Storybook tab stay out of their way and out of the App Store screenshots.
    private static let isUITesting = CommandLine.arguments.contains("-uiTesting")
        || ProcessInfo.processInfo.environment["CARDS_UI_TESTING"] == "1"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([CardItem.self])
        let environment = ProcessInfo.processInfo.environment
        let isTesting = Self.isUITesting
        let seedScreenshots = CommandLine.arguments.contains("-screenshotSeed")
            || environment["CARDS_SCREENSHOT_SEED"] == "1"

        do {
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isTesting)
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            if seedScreenshots {
                let context = container.mainContext
                let seeds = [
                    CardItem(code: "634004024987531", name: "Tesco Clubcard", barcodeType: .ean13, order: 0, color: .blue),
                    CardItem(code: "9780201379624", name: "Boots Advantage", barcodeType: .ean13, order: 1, color: .indigo),
                    CardItem(code: "1234567890128", name: "Costa Coffee", barcodeType: .ean13, order: 2, color: .red),
                    CardItem(code: "9988776655443", name: "Nectar", barcodeType: .code128, order: 3, color: .purple),
                    CardItem(code: "5012345678900", name: "Sainsbury's Nectar", barcodeType: .ean13, order: 4, color: .orange),
                    CardItem(code: "7350053850019", name: "IKEA Family", barcodeType: .code128, order: 5, color: .yellow)
                ]
                seeds.forEach(context.insert)
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
                    CardListScreen()
                        .environment(navigationManager)
                }
                .onAppear {
                    navigationManager.resetToRoot()
                }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsScreen()
                }
            }
            #if DEBUG
            if !Self.isUITesting {
                Tab("Storybook", systemImage: "square.grid.2x2") {
                    StorybookView()
                }
            }
            #endif
        }
        .tint(.accent)
        .environment(locationService)
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
