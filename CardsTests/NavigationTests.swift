import XCTest
import SwiftData
@testable import Cards

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
    
    func testNavigationRouteFromPath() throws {
        XCTAssertEqual(NavigationRoute.from(path: "/cards"), .cards)
        XCTAssertEqual(NavigationRoute.from(path: "/cards/new"), .newCard)
        XCTAssertEqual(NavigationRoute.from(path: "/cards/new/camera"), .camera)
        XCTAssertEqual(NavigationRoute.from(path: "/cards/card/123"), .card("123"))
        XCTAssertEqual(NavigationRoute.from(path: "/cards/card/123/edit"), .editCard("123"))
        
        // Invalid paths
        XCTAssertNil(NavigationRoute.from(path: "/invalid"))
        XCTAssertNil(NavigationRoute.from(path: "/cards/invalid"))
        XCTAssertNil(NavigationRoute.from(path: "/cards/card"))
        XCTAssertNil(NavigationRoute.from(path: "/cards/card/123/invalid"))
    }
    
    func testNavigationRoutePathProperty() throws {
        XCTAssertEqual(NavigationRoute.cards.path, "/cards")
        XCTAssertEqual(NavigationRoute.newCard.path, "/cards/new")
        XCTAssertEqual(NavigationRoute.camera.path, "/cards/new/camera")
        XCTAssertEqual(NavigationRoute.card("123").path, "/cards/card/123")
        XCTAssertEqual(NavigationRoute.editCard("123").path, "/cards/card/123/edit")
    }
    
    func testNavigationRouteId() throws {
        XCTAssertEqual(NavigationRoute.cards.id, "cards")
        XCTAssertEqual(NavigationRoute.newCard.id, "newCard")
        XCTAssertEqual(NavigationRoute.camera.id, "camera")
        XCTAssertEqual(NavigationRoute.card("123").id, "card-123")
        XCTAssertEqual(NavigationRoute.editCard("123").id, "editCard-123")
    }
    
    // MARK: - Navigation Manager Tests
    
    func testNavigateToCards() throws {
        navigationManager.navigate(to: .cards)
        
        XCTAssertEqual(navigationManager.currentRoute, .cards)
        XCTAssertEqual(navigationManager.navigationPath.count, 0)
    }
    
    func testNavigateToCard() throws {
        navigationManager.navigate(to: .card("123"))
        
        XCTAssertEqual(navigationManager.currentRoute, .card("123"))
        XCTAssertEqual(navigationManager.navigationPath.count, 1)
    }
    
    func testNavigateToEditCard() throws {
        navigationManager.navigate(to: .editCard("123"))
        
        XCTAssertEqual(navigationManager.currentRoute, .editCard("123"))
        XCTAssertEqual(navigationManager.navigationPath.count, 2)
    }
    
    func testNavigateToNewCard() throws {
        navigationManager.navigate(to: .newCard)
        
        XCTAssertEqual(navigationManager.currentRoute, .newCard)
        XCTAssertEqual(navigationManager.navigationPath.count, 1)
    }
    
    func testNavigateToCamera() throws {
        navigationManager.navigate(to: .camera)
        
        XCTAssertEqual(navigationManager.currentRoute, .camera)
        XCTAssertEqual(navigationManager.navigationPath.count, 2)
    }
    
    // MARK: - Deep Link Tests
    
    func testDeepLinkToCards() throws {
        let url = URL(string: "cards:///cards")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .cards)
    }
    
    func testDeepLinkToNewCard() throws {
        let url = URL(string: "cards:///cards/new")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .newCard)
    }
    
    func testDeepLinkToCamera() throws {
        let url = URL(string: "cards:///cards/new/camera")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .camera)
    }
    
    func testDeepLinkToCard() throws {
        let url = URL(string: "cards:///cards/card/123456")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .card("123456"))
    }
    
    func testDeepLinkToEditCard() throws {
        let url = URL(string: "cards:///cards/card/123456/edit")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .editCard("123456"))
    }
    
    func testDeepLinkWithInvalidScheme() throws {
        let url = URL(string: "invalid:///cards")!
        
        navigationManager.handleDeepLink(url)
        
        // Should remain at default route
        XCTAssertEqual(navigationManager.currentRoute, .cards)
    }
    
    func testDeepLinkWithInvalidPath() throws {
        let url = URL(string: "cards:///invalid")!
        
        navigationManager.handleDeepLink(url)
        
        // Should remain at default route
        XCTAssertEqual(navigationManager.currentRoute, .cards)
    }
    
    func testDeepLinkToNonExistentCard() throws {
        let url = URL(string: "cards:///cards/card/nonexistent")!
        
        navigationManager.handleDeepLink(url)
        
        // Should navigate even if card doesn't exist (UI will handle gracefully)
        XCTAssertEqual(navigationManager.currentRoute, .card("nonexistent"))
    }
    
    func testDeepLinkToEditNonExistentCard() throws {
        let url = URL(string: "cards:///cards/card/nonexistent/edit")!
        
        navigationManager.handleDeepLink(url)
        
        // Should navigate even if card doesn't exist (UI will handle gracefully)
        XCTAssertEqual(navigationManager.currentRoute, .editCard("nonexistent"))
    }
    
    // MARK: - Navigation Path Validation Tests
    
    func testNavigationPathForComplexFlow() throws {
        // Test a complex navigation flow: Cards -> Card -> Edit
        navigationManager.navigate(to: .cards)
        XCTAssertEqual(navigationManager.navigationPath.count, 0)
        
        navigationManager.navigate(to: .card("123"))
        XCTAssertEqual(navigationManager.navigationPath.count, 1)
        
        navigationManager.navigate(to: .editCard("123"))
        XCTAssertEqual(navigationManager.navigationPath.count, 2)
        
        // Navigate back to cards should clear the path
        navigationManager.navigate(to: .cards)
        XCTAssertEqual(navigationManager.navigationPath.count, 0)
    }
    
    func testNavigationPathForCameraFlow() throws {
        // Test camera flow: Cards -> New -> Camera
        navigationManager.navigate(to: .cards)
        XCTAssertEqual(navigationManager.navigationPath.count, 0)
        
        navigationManager.navigate(to: .newCard)
        XCTAssertEqual(navigationManager.navigationPath.count, 1)
        
        navigationManager.navigate(to: .camera)
        XCTAssertEqual(navigationManager.navigationPath.count, 2)
    }
    
    // MARK: - Edge Cases
    
    func testDeepLinkWithEmptyPath() throws {
        let url = URL(string: "cards://")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .cards)
    }
    
    func testDeepLinkWithSpecialCharactersInCardCode() throws {
        let url = URL(string: "cards:///cards/card/ABC-123_456")!
        
        navigationManager.handleDeepLink(url)
        
        XCTAssertEqual(navigationManager.currentRoute, .card("ABC-123_456"))
    }
}
