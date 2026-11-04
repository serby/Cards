import Foundation

public enum NavigationRoute: Hashable, Identifiable, Codable {
    case cards
    case card(String)
    case editCard(String)
    case newCard

    public var id: String {
        switch self {
        case .cards:
            return "cards"
        case .card(let code):
            return "card-\(code)"
        case .editCard(let code):
            return "editCard-\(code)"
        case .newCard:
            return "newCard"
        }
    }

    public var path: String {
        switch self {
        case .cards:
            return "/cards"
        case .card(let code):
            return "/cards/card/\(code)"
        case .editCard(let code):
            return "/cards/card/\(code)/edit"
        case .newCard:
            return "/cards/new"
        }
    }

    public static func from(path: String) -> Self? {
        from(components: Array(path.components(separatedBy: "/").dropFirst()))
    }

    /// The route a `cards://cards/...` link opens, or nil for any other link.
    /// Each path segment is decoded on its own, so a code may contain "/".
    public static func from(url: URL) -> Self? {
        guard url.scheme == Self.scheme, url.host == Self.host,
              let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath else {
            return nil
        }
        let components = path.components(separatedBy: "/").dropFirst().map { $0.removingPercentEncoding ?? $0 }
        return from(components: components)
    }

    /// A link that opens this route, as `from(url:)` reads it.
    public var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.percentEncodedPath = linkSegments
            .map { "/" + ($0.addingPercentEncoding(withAllowedCharacters: Self.segmentCharacters) ?? $0) }
            .joined()
        return components.url
    }

    private static let scheme = "cards"
    private static let host = "cards"
    /// The unreserved URL characters, which a path segment keeps as they are.
    /// Everything else, "/" and non-ASCII letters included, is percent-encoded.
    private static let segmentCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    private var linkSegments: [String] {
        switch self {
        case .cards:
            []
        case .card(let code):
            ["card", code]
        case .editCard(let code):
            ["card", code, "edit"]
        case .newCard:
            ["new"]
        }
    }

    private static func from(components: [String]) -> Self? {
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
