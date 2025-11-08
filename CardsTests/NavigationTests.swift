@testable import Cards
import SwiftData
import XCTest

final class NavigationTests: XCTestCase {
    var navigationManager: NavigationManager!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        navigationManager = NavigationManager()
        
        let schema = Schema([CardItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDownWithError() throws {
        navigationManager = nil
        modelContext = nil
        modelContainer = nil
    }
    
    // MARK: - Navigation Route Tests
    
    func test_navigationRouteFromPath_validPaths_returnsCorrectRoutes() throws {
        // Test valid paths
        XCTAssertEqual(NavigationRoute.from(path: "/new"), .newCard)
        XCTAssertEqual(NavigationRoute.from(path: "/card/123"), .card("123"))
        XCTAssertEqual(NavigationRoute.from(path: "/new/camera"), .camera)
        XCTAssertEqual(NavigationRoute.from(path: "/card/123/edit"), .editCard("123"))
    }
    
    func test_navigationRouteFromPath_defaultCase_returnsCards() throws {
        // Test default case (0 components or other counts)
        XCTAssertEqual(NavigationRoute.from(path: ""), .cards)
        XCTAssertEqual(NavigationRoute.from(path: "/"), .cards)
        XCTAssertEqual(NavigationRoute.from(path: "/cards"), .cards)
        XCTAssertEqual(NavigationRoute.from(path: "/cards/extra/path/components"), .cards)
        XCTAssertEqual(NavigationRoute.from(path: "/invalid/path/with/many/components"), .cards)
    }
    
    func test_navigationRouteFromPath_invalidSingleComponent_returnsCards() throws {
        // Test invalid single component
        XCTAssertEqual(NavigationRoute.from(path: "/invalid"), .cards)
        XCTAssertEqual(NavigationRoute.from(path: "/cards"), .cards)
    }
    
    func test_navigationRouteFromPath_invalidTwoComponents_returnsCards() throws {
        // Test invalid two component combinations
        XCTAssertEqual(NavigationRoute.from(path: "/invalid/path"), .cards)
        XCTAssertEqual(NavigationRoute.from(path: "/card/"), .cards) // Empty second component
        XCTAssertEqual(NavigationRoute.from(path: "/new/invalid"), .cards)
    }
    
    func test_navigationRouteFromPath_invalidThreeComponents_returnsCards() throws {
        // Test invalid three component combinations
        XCTAssertEqual(NavigationRoute.from(path: "/invalid/123/edit"), .cards)
        XCTAssertEqual(NavigationRoute.from(path: "/card/123/invalid"), .cards)
        XCTAssertEqual(NavigationRoute.from(path: "/card//edit"), .cards) // Empty middle component
    }
    
    func test_navigationRouteFromPath_emptyComponents_handledCorrectly() throws {
        // Test paths with empty components after filtering
        XCTAssertEqual(NavigationRoute.from(path: "///"), .cards)
        XCTAssertEqual(NavigationRoute.from(path: "/new//"), .cards)
        XCTAssertEqual(NavigationRoute.from(path: "//card/123"), .cards)
    }
    
    func test_navigationRoutePathProperty_allCases_returnCorrectPaths() throws {
        XCTAssertEqual(NavigationRoute.cards.path, "/cards")
        XCTAssertEqual(NavigationRoute.newCard.path, "/cards/new")
        XCTAssertEqual(NavigationRoute.camera.path, "/cards/new/camera")
        XCTAssertEqual(NavigationRoute.card("123").path, "/cards/card/123")
        XCTAssertEqual(NavigationRoute.editCard("123").path, "/cards/card/123/edit")
    }
    
    func test_navigationRouteId_allCases_returnCorrectIds() throws {
        XCTAssertEqual(NavigationRoute.cards.id, "cards")
        XCTAssertEqual(NavigationRoute.newCard.id, "newCard")
        XCTAssertEqual(NavigationRoute.camera.id, "camera")
        XCTAssertEqual(NavigationRoute.card("123").id, "card-123")
        XCTAssertEqual(NavigationRoute.editCard("123").id, "editCard-123")
    }
    
    // MARK: - Navigation Manager Tests
    
    func test_navigateToCards_clearsPath() throws {
        navigationManager.navigate(to: .cards)
        
        XCTAssertEqual(navigationManager.currentRoute, .cards)
        XCTAssertEqual(navigationManager.navigationPath.count, 0)
    }
    
    func test_navigateToCard_setsCorrectPath() throws {
        navigationManager.navigate(to: .card("123"))
        
        XCTAssertEqual(navigationManager.currentRoute, .card("123"))
        XCTAssertEqual(navigationManager.navigationPath.count, 1)
    }
    
    func test_navigateToEditCard_setsCorrectPath() throws {
        navigationManager.navigate(to: .editCard("123"))
        
        XCTAssertEqual(navigationManager.currentRoute, .editCard("123"))
        XCTAssertEqual(navigationManager.navigationPath.count, 2)
    }
    
    func test_navigateToNewCard_setsCorrectPath() throws {
        navigationManager.navigate(to: .newCard)
        
        XCTAssertEqual(navigationManager.currentRoute, .newCard)
        XCTAssertEqual(navigationManager.navigationPath.count, 1)
    }
    
    func test_navigateToCamera_setsCorrectPath() throws {
        navigationManager.navigate(to: .camera)
        
        XCTAssertEqual(navigationManager.currentRoute, .camera)
        XCTAssertEqual(navigationManager.navigationPath.count, 2)
    }
    
    // MARK: - Deep Link Tests
    
    func test_handleDeepLink_validCardsURL_navigatesCorrectly() throws {
        let url = URL(string: "cards://cards/new")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .newCard)
    }
    
    func test_handleDeepLink_validCardURL_navigatesCorrectly() throws {
        let url = URL(string: "cards://cards/card/123456")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .card("123456"))
    }
    
    func test_handleDeepLink_validEditCardURL_navigatesCorrectly() throws {
        let url = URL(string: "cards://cards/card/123456/edit")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .editCard("123456"))
    }
    
    func test_handleDeepLink_validCameraURL_navigatesCorrectly() throws {
        let url = URL(string: "cards://cards/new/camera")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .camera)
    }
    
    func test_handleDeepLink_invalidScheme_doesNotNavigate() throws {
        let originalRoute = navigationManager.currentRoute
        let url = URL(string: "invalid://cards/new")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, originalRoute)
    }
    
    func test_handleDeepLink_invalidHost_doesNotNavigate() throws {
        let originalRoute = navigationManager.currentRoute
        let url = URL(string: "cards://invalid/new")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, originalRoute)
    }
    
    func test_handleDeepLink_noHost_doesNotNavigate() throws {
        let originalRoute = navigationManager.currentRoute
        let url = URL(string: "cards:///new")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, originalRoute)
    }
    
    func test_handleDeepLink_invalidPath_navigatesToCards() throws {
        let url = URL(string: "cards://cards/invalid/path")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .cards)
    }
    
    func test_handleDeepLink_emptyPath_navigatesToCards() throws {
        let url = URL(string: "cards://cards")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .cards)
    }
    
    func test_handleDeepLink_rootPath_navigatesToCards() throws {
        let url = URL(string: "cards://cards/")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .cards)
    }
    
    func test_handleDeepLink_specialCharactersInCardCode_handlesCorrectly() throws {
        let url = URL(string: "cards://cards/card/ABC-123_456")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .card("ABC-123_456"))
    }
    
    // MARK: - Navigation Path Validation Tests
    
    func test_navigationPath_complexFlow_maintainsCorrectCounts() throws {
        // Test complex navigation flow
        navigationManager.navigate(to: .cards)
        XCTAssertEqual(navigationManager.navigationPath.count, 0)
        
        navigationManager.navigate(to: .card("123"))
        XCTAssertEqual(navigationManager.navigationPath.count, 1)
        
        navigationManager.navigate(to: .editCard("123"))
        XCTAssertEqual(navigationManager.navigationPath.count, 2)
        
        navigationManager.navigate(to: .cards)
        XCTAssertEqual(navigationManager.navigationPath.count, 0)
    }
    
    func test_navigationPath_cameraFlow_maintainsCorrectCounts() throws {
        navigationManager.navigate(to: .newCard)
        XCTAssertEqual(navigationManager.navigationPath.count, 1)
        
        navigationManager.navigate(to: .camera)
        XCTAssertEqual(navigationManager.navigationPath.count, 2)
        
        navigationManager.navigate(to: .cards)
        XCTAssertEqual(navigationManager.navigationPath.count, 0)
    }
    
    func test_navigationPath_allRoutes_clearPathCorrectly() throws {
        // Test that all routes properly clear and rebuild the path
        let routes: [NavigationRoute] = [
            .cards, .card("test"), .editCard("test"), .newCard, .camera
        ]
        
        for route in routes {
            navigationManager.navigate(to: route)
            XCTAssertEqual(navigationManager.currentRoute, route)
            
            // Verify path count matches expected for each route
            switch route {
            case .cards:
                XCTAssertEqual(navigationManager.navigationPath.count, 0)
            case .card, .newCard:
                XCTAssertEqual(navigationManager.navigationPath.count, 1)
            case .editCard, .camera:
                XCTAssertEqual(navigationManager.navigationPath.count, 2)
            }
        }
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func test_navigationRoute_hashable_worksCorrectly() throws {
        let route1 = NavigationRoute.card("123")
        let route2 = NavigationRoute.card("123")
        let route3 = NavigationRoute.card("456")
        
        XCTAssertEqual(route1, route2)
        XCTAssertNotEqual(route1, route3)
        
        let set: Set<NavigationRoute> = [route1, route2, route3]
        XCTAssertEqual(set.count, 2) // route1 and route2 should be the same
    }
    
    func test_navigationRoute_identifiable_providesUniqueIds() throws {
        let routes: [NavigationRoute] = [
            .cards, .card("123"), .editCard("123"), .newCard, .camera
        ]
        
        let ids = routes.map { $0.id }
        let uniqueIds = Set(ids)
        
        XCTAssertEqual(ids.count, uniqueIds.count) // All IDs should be unique
    }
}
