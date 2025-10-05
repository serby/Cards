import Foundation

enum NavigationRoute: Hashable, Identifiable {
    case cards
    case card(String)
    case editCard(String)
    case newCard
    case camera
    
    var id: String {
        switch self {
        case .cards:
            return "cards"
        case .card(let code):
            return "card-\(code)"
        case .editCard(let code):
            return "editCard-\(code)"
        case .newCard:
            return "newCard"
        case .camera:
            return "camera"
        }
    }
    
    var path: String {
        switch self {
        case .cards:
            return "/cards"
        case .card(let code):
            return "/cards/card/\(code)"
        case .editCard(let code):
            return "/cards/card/\(code)/edit"
        case .newCard:
            return "/cards/new"
        case .camera:
            return "/cards/new/camera"
        }
    }
    
    static func from(path: String) -> NavigationRoute? {
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        guard components.first == "cards" else { return nil }
        
        switch components.count {
        case 1:
            return .cards
        case 2:
            if components[1] == "new" {
                return .newCard
            }
        case 3:
            if components[1] == "card" {
                return .card(components[2])
            } else if components[1] == "new" && components[2] == "camera" {
                return .camera
            }
        case 4:
            if components[1] == "card" && components[3] == "edit" {
                return .editCard(components[2])
            }
        default:
            break
        }
        
        return nil
    }
}
