@testable import CardsCore
import Foundation
import SwiftData
import Testing

struct NavigationTests {
    var navigationManager: NavigationManager
    var modelContainer: ModelContainer
    var modelContext: ModelContext

    init() throws {
        navigationManager = NavigationManager()
        let schema = Schema([CardItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }

    @Test func navigationRouteFromPath_validPaths_returnsCorrectRoutes() throws {
        #expect(NavigationRoute.from(path: "/new") == .newCard)
        #expect(NavigationRoute.from(path: "/card/123") == .card("123"))
        #expect(NavigationRoute.from(path: "/card/123/edit") == .editCard("123"))
    }

    @Test func navigationRouteFromPath_cameraPath_returnsCards() throws {
        #expect(NavigationRoute.from(path: "/new/camera") == .cards)
    }

    @Test func navigationRouteFromPath_defaultCase_returnsCards() throws {
        #expect(NavigationRoute.from(path: "") == .cards)
        #expect(NavigationRoute.from(path: "/") == .cards)
        #expect(NavigationRoute.from(path: "/cards") == .cards)
        #expect(NavigationRoute.from(path: "/cards/extra/path/components") == .cards)
        #expect(NavigationRoute.from(path: "/invalid/path/with/many/components") == .cards)
    }

    @Test func navigationRouteFromPath_invalidSingleComponent_returnsCards() throws {
        #expect(NavigationRoute.from(path: "/invalid") == .cards)
        #expect(NavigationRoute.from(path: "/cards") == .cards)
    }

    @Test func navigationRouteFromPath_invalidTwoComponents_returnsCards() throws {
        #expect(NavigationRoute.from(path: "/invalid/path") == .cards)
        #expect(NavigationRoute.from(path: "/card/") == .cards)
        #expect(NavigationRoute.from(path: "/new/invalid") == .cards)
    }

    @Test func navigationRouteFromPath_invalidThreeComponents_returnsCards() throws {
        #expect(NavigationRoute.from(path: "/invalid/123/edit") == .cards)
        #expect(NavigationRoute.from(path: "/card/123/invalid") == .cards)
        #expect(NavigationRoute.from(path: "/card//edit") == .cards)
    }

    @Test func navigationRouteFromPath_emptyComponents_handledCorrectly() throws {
        #expect(NavigationRoute.from(path: "///") == .cards)
        #expect(NavigationRoute.from(path: "/new//") == .cards)
        #expect(NavigationRoute.from(path: "//card/123") == .cards)
    }

    @Test func navigationRoutePathProperty_allCases_returnCorrectPaths() throws {
        #expect(NavigationRoute.cards.path == "/cards")
        #expect(NavigationRoute.newCard.path == "/cards/new")
        #expect(NavigationRoute.card("123").path == "/cards/card/123")
        #expect(NavigationRoute.editCard("123").path == "/cards/card/123/edit")
    }

    @Test func navigationRouteId_allCases_returnCorrectIds() throws {
        #expect(NavigationRoute.cards.id == "cards")
        #expect(NavigationRoute.newCard.id == "newCard")
        #expect(NavigationRoute.card("123").id == "card-123")
        #expect(NavigationRoute.editCard("123").id == "editCard-123")
    }

    @Test func navigateToCards_clearsPath() throws {
        navigationManager.navigate(to: .cards)
        #expect(navigationManager.currentRoute == .cards)
        #expect(navigationManager.navigationPath.count == 0)
    }

    @Test func navigateToCard_setsCorrectPath() throws {
        navigationManager.navigate(to: .card("123"))
        #expect(navigationManager.currentRoute == .card("123"))
        #expect(navigationManager.navigationPath.count == 1)
    }

    @Test func navigateToEditCard_setsCorrectPath() throws {
        navigationManager.navigate(to: .editCard("123"))
        #expect(navigationManager.currentRoute == .editCard("123"))
        #expect(navigationManager.navigationPath.count == 2)
    }

    @Test func navigateToNewCard_setsCorrectPath() throws {
        navigationManager.navigate(to: .newCard)
        #expect(navigationManager.currentRoute == .newCard)
        #expect(navigationManager.navigationPath.count == 1)
    }

    @Test func resetToRoot_resetsUnconditionally() throws {
        navigationManager.navigate(to: .editCard("123"))
        #expect(navigationManager.navigationPath.count == 2)
        navigationManager.resetToRoot()
        #expect(navigationManager.navigationPath.count == 0)
        #expect(navigationManager.currentRoute == .cards)
    }

    @Test func handleDeepLink_validCardsURL_navigatesCorrectly() throws {
        let url = try #require(URL(string: "cards://cards/new"))
        navigationManager.handleDeepLink(url)
        #expect(navigationManager.currentRoute == .newCard)
    }

    @Test func handleDeepLink_validCardURL_navigatesCorrectly() throws {
        let url = try #require(URL(string: "cards://cards/card/123456"))
        navigationManager.handleDeepLink(url)
        #expect(navigationManager.currentRoute == .card("123456"))
    }

    @Test func handleDeepLink_validEditCardURL_navigatesCorrectly() throws {
        let url = try #require(URL(string: "cards://cards/card/123456/edit"))
        navigationManager.handleDeepLink(url)
        #expect(navigationManager.currentRoute == .editCard("123456"))
    }

    @Test func handleDeepLink_invalidScheme_doesNotNavigate() throws {
        let originalRoute = navigationManager.currentRoute
        let url = try #require(URL(string: "invalid://cards/new"))
        navigationManager.handleDeepLink(url)
        #expect(navigationManager.currentRoute == originalRoute)
    }

    @Test func handleDeepLink_invalidHost_doesNotNavigate() throws {
        let originalRoute = navigationManager.currentRoute
        let url = try #require(URL(string: "cards://invalid/new"))
        navigationManager.handleDeepLink(url)
        #expect(navigationManager.currentRoute == originalRoute)
    }

    @Test func handleDeepLink_noHost_doesNotNavigate() throws {
        let originalRoute = navigationManager.currentRoute
        let url = try #require(URL(string: "cards:///new"))
        navigationManager.handleDeepLink(url)
        #expect(navigationManager.currentRoute == originalRoute)
    }

    @Test func handleDeepLink_invalidPath_navigatesToCards() throws {
        let url = try #require(URL(string: "cards://cards/invalid/path"))
        navigationManager.handleDeepLink(url)
        #expect(navigationManager.currentRoute == .cards)
    }

    @Test func handleDeepLink_emptyPath_navigatesToCards() throws {
        let url = try #require(URL(string: "cards://cards"))
        navigationManager.handleDeepLink(url)
        #expect(navigationManager.currentRoute == .cards)
    }

    @Test func handleDeepLink_rootPath_navigatesToCards() throws {
        let url = try #require(URL(string: "cards://cards/"))
        navigationManager.handleDeepLink(url)
        #expect(navigationManager.currentRoute == .cards)
    }

    @Test func handleDeepLink_specialCharactersInCardCode_handlesCorrectly() throws {
        let url = try #require(URL(string: "cards://cards/card/ABC-123_456"))
        navigationManager.handleDeepLink(url)
        #expect(navigationManager.currentRoute == .card("ABC-123_456"))
    }

    @Test func navigationPath_complexFlow_maintainsCorrectCounts() throws {
        navigationManager.navigate(to: .cards)
        #expect(navigationManager.navigationPath.count == 0)
        navigationManager.navigate(to: .card("123"))
        #expect(navigationManager.navigationPath.count == 1)
        navigationManager.navigate(to: .editCard("123"))
        #expect(navigationManager.navigationPath.count == 2)
        navigationManager.navigate(to: .cards)
        #expect(navigationManager.navigationPath.count == 0)
    }

    @Test func navigationPath_allRoutes_clearPathCorrectly() throws {
        let routes: [NavigationRoute] = [
            .cards, .card("test"), .editCard("test"), .newCard
        ]
        for route in routes {
            navigationManager.navigate(to: route)
            #expect(navigationManager.currentRoute == route)
            switch route {
            case .cards:
                #expect(navigationManager.navigationPath.count == 0)
            case .card, .newCard:
                #expect(navigationManager.navigationPath.count == 1)
            case .editCard:
                #expect(navigationManager.navigationPath.count == 2)
            }
        }
    }

    @Test func navigationRoute_hashable_worksCorrectly() throws {
        let route1 = NavigationRoute.card("123")
        let route2 = NavigationRoute.card("123")
        let route3 = NavigationRoute.card("456")
        #expect(route1 == route2)
        #expect(route1 != route3)
        let set: Set<NavigationRoute> = [route1, route2, route3]
        #expect(set.count == 2)
    }

    @Test func navigationRoute_identifiable_providesUniqueIds() throws {
        let routes: [NavigationRoute] = [
            .cards, .card("123"), .editCard("123"), .newCard
        ]
        let ids = routes.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }
}
