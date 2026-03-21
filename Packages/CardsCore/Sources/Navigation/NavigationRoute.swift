import Foundation

public enum NavigationRoute: Hashable, Identifiable, Codable {
    case cards
    case card(String)
    case editCard(String)
    case newCard

    public var id: String {
        switch self {
        case .cards:            return "cards"
        case .card(let code):   return "card-\(code)"
        case .editCard(let code): return "editCard-\(code)"
        case .newCard:          return "newCard"
        }
    }

    public var path: String {
        switch self {
        case .cards:            return "/cards"
        case .card(let code):   return "/cards/card/\(code)"
        case .editCard(let code): return "/cards/card/\(code)/edit"
        case .newCard:          return "/cards/new"
        }
    }

    public static func from(path: String) -> NavigationRoute? {
        let components = Array(path.components(separatedBy: "/").dropFirst())
        let hasUnexpectedEmptyElements = components.contains("")
        if hasUnexpectedEmptyElements { return .cards }

        switch components.count {
        case 1:
            if components[0] == "new" { return .newCard }
        case 2:
            if components[0] == "card" { return .card(components[1]) }
        case 3:
            if components[0] == "card" && components[2] == "edit" { return .editCard(components[1]) }
        default:
            return .cards
        }
        return .cards
    }
}
