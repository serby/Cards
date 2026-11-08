import SwiftData
import SwiftUI
import UserNotifications

@main
struct CardsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigationManager: NavigationManager
    @State private var locationService = LocationService(fixedLocation: DevelopmentHooks.screenshotLocation)
    @State private var arrivalScheduler = ArrivalScheduler(notifications: DevelopmentHooks.notifications)
    /// Set in Settings, and handed to every screen and the widget from here (SET-4).
    @AppStorage(DeviceSettings.distanceUnitsKey) private var distanceUnits = DistanceUnits.automatic
    /// Set in Settings (DATA-8). Changing it opens the store again, with or
    /// without iCloud, on the same file.
    @AppStorage(DeviceSettings.syncsWithICloudKey) private var syncsWithICloud = true
    @State private var modelContainer: ModelContainer
    private let widgetSettings = WidgetSettings.live
    private let performanceTracker = PerformanceTracker()
    private let arrivalRouter: ArrivalNotificationRouter

    init() {
        DevelopmentHooks.disableAnimationsIfRequested()
        let navigationManager = NavigationManager()
        _navigationManager = State(initialValue: navigationManager)
        // Set before launch finishes so a tap that launched the app is not missed.
        // Handing iOS its delegate is wiring, so it is done here at the composition
        // root rather than through the notification client.
        arrivalRouter = ArrivalNotificationRouter { code in
            navigationManager.navigate(to: .card(code))
        }
        UNUserNotificationCenter.current().delegate = arrivalRouter
        let syncs = UserDefaults.standard.object(forKey: DeviceSettings.syncsWithICloudKey) as? Bool ?? true
        DevelopmentHooks.initializeCloudKitSchemaIfRequested()
        let container = Self.makeModelContainer(syncsWithICloud: syncs)
        do {
            try DevelopmentHooks.seedScreenshotCards(into: container)
        } catch {
            fatalError("Seeding the screenshot cards failed: \(error)")
        }
        _modelContainer = State(initialValue: container)
    }

    /// The cards' store, syncing with iCloud or not (CardStore).
    private static func makeModelContainer(syncsWithICloud: Bool) -> ModelContainer {
        do {
            let configuration = CardStore.configuration(inMemory: DevelopmentHooks.isUITesting, syncsWithICloud: syncsWithICloud)
            return try ModelContainer(for: CardStore.schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer failed: \(error)")
        }
    }

    @ViewBuilder
    private var tabView: some View {
        let nav = Bindable(navigationManager)
        TabView(selection: nav.tab) {
            // The stack keeps its place when you switch tabs, so a card opened from
            // a link or notification while Settings was showing is still there.
            // Tab's own title-and-image initialisers that take a comment need iOS 26.
            Tab(value: AppTab.cards) {
                NavigationStack(path: nav.navigationPath) {
                    CardListScreen()
                        .environment(navigationManager)
                }
                // A new store means new card screens, so none keeps a card of the
                // old one. Settings stays as it is, where the switch was turned.
                .id(ObjectIdentifier(modelContainer))
            } label: {
                Label(
                    LocalizedStringResource("Cards", comment: "Tab bar item for the list of the user's loyalty cards."),
                    systemImage: "barcode"
                )
            }
            Tab(value: AppTab.settings) {
                NavigationStack {
                    SettingsScreen()
                }
            } label: {
                Label(LocalizedStringResource("Settings", comment: "Tab bar item for the app's settings."), systemImage: "gearshape")
            }
            DevelopmentHooks.tabs
        }
        // Presented from the root, over whatever the Cards tab shows, so Cancel
        // leaves it as it was. Inside the tint, so the sheet takes the accent.
        .sheet(item: nav.sharedCard) { link in
            SharedCardScreen(link: link, navigationManager: navigationManager)
        }
        .tint(.accent)
        .environment(locationService)
        .environment(arrivalScheduler)
        .environment(\.mapShowsPointsOfInterest, DevelopmentHooks.mapShowsPointsOfInterest)
        .environment(\.placeSearch, DevelopmentHooks.placeSearch)
        .environment(\.distanceUnits, distanceUnits)
        // The widget runs in its own process, so it gets a copy of the choice.
        .onChange(of: distanceUnits, initial: true) {
            widgetSettings.setDistanceUnits(distanceUnits)
        }
        .background(Color.primaryBackground)
        .onAppear {
            performanceTracker.recordAppLaunch()
        }
        .onOpenURL(perform: navigationManager.handleDeepLink)
        // A universal link, such as a card shared from cards.serby.net (SHARE-3).
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL {
                navigationManager.handleDeepLink(url)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            tabView
                .onChange(of: syncsWithICloud) {
                    // An in-memory store (UI tests) never syncs, and a new one would be empty.
                    guard !DevelopmentHooks.isUITesting else { return }
                    modelContainer = Self.makeModelContainer(syncsWithICloud: syncsWithICloud)
                }
        }
        .modelContainer(modelContainer)
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
