import SwiftData
import SwiftUI

class NavigationManager: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var currentRoute: NavigationRoute = .cards
    
    func navigate(to route: NavigationRoute) {
        objectWillChange.send()
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
    
    func resetToRoot() {
        if case .camera = currentRoute {
            objectWillChange.send()
            navigationPath = NavigationPath()
            currentRoute = .cards
        }
    }
    
    func handleDeepLink(_ url: URL) {
        print("Deep Link Recieved: \(url) - Schema: \(url.scheme ?? "nil") Host: \(url.host ?? "nil") Path: \(url.path)")
        guard url.scheme == "cards" && url.host == "cards" else {
            print("Scheme not recognized: \(url)")
            return
        }
        guard let route = NavigationRoute.from(path: url.path) else {
            print("Invalid path: \(url.path)")
            return
        }
        print("Navigating to route: \(route)")
        navigate(to: route)
    }
}
