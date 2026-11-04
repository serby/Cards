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

    var sharedModelContainer: ModelContainer = {
        do {
            let modelConfiguration = CardStore.configuration(inMemory: DevelopmentHooks.isUITesting)
            DevelopmentHooks.initializeCloudKitSchemaIfRequested()
            let container = try ModelContainer(for: CardStore.schema, configurations: [modelConfiguration])
            try DevelopmentHooks.seedScreenshotCards(into: container)
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
            DevelopmentHooks.tabs
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
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch (oldPhase, newPhase) {
            // A warm start runs from leaving the background to being active. Going
            // inactive without backgrounding (Control Centre, the app switcher) is not one.
            case (.background, .inactive):
                performanceTracker.recordForegroundTransition()
            case (_, .active):
                performanceTracker.recordWarmStart()
            case (_, .background):
                performanceTracker.recordBackgroundTransition()
            default:
                break
            }
        }
    }
}
