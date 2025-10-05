import SwiftUI
import SwiftData

class NavigationManager: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var currentRoute: NavigationRoute = .cards
    
    func navigate(to route: NavigationRoute) {
        currentRoute = route
        
        switch route {
        case .cards:
            navigationPath = NavigationPath()
        case .card(_):
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
    
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "cards" else { return }
        
        let path = url.path.isEmpty ? "/cards" : url.path
        guard let route = NavigationRoute.from(path: path) else { return }
        
        navigate(to: route)
    }
}
