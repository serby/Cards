import Foundation

/// A link that shares a card (SHARE-1, SHARE-3). The app writes
/// `https://cards.serby.net/add#<payload>`, which opens Card Barcodes as a
/// universal link, or the website's page about it on a device without the app.
/// It also reads `cards://cards/add#<payload>`, for the simulator and as a
/// fallback when universal links are not set up. The payload is a
/// `SharedCard`'s, or whatever else a link held after the "#".
public struct SharedCardLink: Hashable, Identifiable, Sendable {
    /// The text after the "#", which may hold no card at all.
    public let payload: String

    public var id: String { payload }

    public init(payload: String) {
        self.payload = payload
    }

    public init(card: SharedCard) {
        self.init(payload: card.payload)
    }

    /// The share link in `url`, or nil when it is some other link. A share link
    /// without a "#" has an empty payload.
    public init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              (scheme, host) == (Self.webScheme, Self.webHost) || (scheme, host) == (NavigationRoute.scheme, NavigationRoute.host),
              components.percentEncodedPath == Self.path else {
            return nil
        }
        payload = components.fragment ?? ""
    }

    /// The link to send: the website's, which opens the app where it is installed.
    public var url: URL? {
        link(scheme: Self.webScheme, host: Self.webHost)
    }

    /// The same link in the app's own scheme.
    public var appURL: URL? {
        link(scheme: NavigationRoute.scheme, host: NavigationRoute.host)
    }

    /// The card the link holds, or nil if it holds none.
    public var card: SharedCard? {
        SharedCard(payload: payload)
    }

    /// The website the links point at. Its `apple-app-site-association` lists `path`.
    static let webScheme = "https"
    static let webHost = "cards.serby.net"
    static let path = "/add"

    private func link(scheme: String, host: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.percentEncodedPath = Self.path
        components.fragment = payload
        return components.url
    }
}
