import SwiftUI

@Observable public final class NavigationManager {
    public var navigationPath = NavigationPath()
    public var currentRoute: NavigationRoute = .cards

    public init() {}

    public func navigate(to route: NavigationRoute) {
        currentRoute = route
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
        case .camera:
            navigationPath = NavigationPath()
            navigationPath.append(NavigationRoute.newCard)
            navigationPath.append(route)
        }
    }

    public func resetToRoot() {
        if case .camera = currentRoute {
            navigationPath = NavigationPath()
            currentRoute = .cards
        }
    }

    public func handleDeepLink(_ url: URL) {
        guard url.scheme == "cards" && url.host == "cards" else { return }
        guard let route = NavigationRoute.from(path: url.path) else { return }
        navigate(to: route)
    }
}
