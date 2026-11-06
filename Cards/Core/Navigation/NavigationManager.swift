import SwiftUI

@Observable public final class NavigationManager {
    public var navigationPath = NavigationPath()
    public var currentRoute: NavigationRoute = .cards
    /// The selected tab. Every route lives in the Cards tab, so opening one, from a
    /// link, the widget or a notification, also brings that tab forward.
    public var tab: AppTab = .cards
    /// A card someone shared, shown in the "Add Card?" sheet over the Cards tab
    /// (SHARE-3); nil when the sheet is not showing.
    public var sharedCard: SharedCardLink?

    public init() {}

    public func navigate(to route: NavigationRoute) {
        currentRoute = route
        tab = .cards
        // The sheet makes way for the screen the route opens, such as the card it added.
        sharedCard = nil
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

    /// Brings the Cards tab forward and asks whether to add the shared card. The
    /// tab keeps what it was showing, so Cancel goes back to it.
    public func show(_ link: SharedCardLink) {
        tab = .cards
        sharedCard = link
    }

    /// Opens a link from outside the app: a share link (SHARE-3), or a
    /// `cards://` link to a screen (NAV-2). Any other link is ignored.
    public func handleDeepLink(_ url: URL) {
        if let link = SharedCardLink(url: url) {
            show(link)
            return
        }
        guard let route = NavigationRoute.from(url: url) else { return }
        navigate(to: route)
    }
}
