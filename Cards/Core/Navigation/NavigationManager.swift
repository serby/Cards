import SwiftUI

@Observable public final class NavigationManager {
    public var navigationPath = NavigationPath()
    public var currentRoute: NavigationRoute = .cards
    /// The selected tab. Every route lives in the Cards tab, so opening one, from a
    /// link, the widget or a notification, also brings that tab forward.
    public var tab: AppTab = .cards

    public init() {}

    public func navigate(to route: NavigationRoute) {
        currentRoute = route
        tab = .cards
        switch route {
        case .cards:
            navigationPath = NavigationPath()
        case .card:
            navigationPath = NavigationPath()
            navigationPath.append(route)
        case .editCard(let code):
            navigationPath = NavigationPath()
            navigationPath.append(NavigationRoute.card(code))
            navigationPath.append(route)
        case .newCard:
            navigationPath = NavigationPath()
            navigationPath.append(route)
        }
    }

    public func resetToRoot() {
        navigationPath = NavigationPath()
        currentRoute = .cards
    }

    public func handleDeepLink(_ url: URL) {
        guard let route = NavigationRoute.from(url: url) else { return }
        navigate(to: route)
    }
}
