import XCTest
import SwiftData
@testable import Cards

final class DeepLinkTests: XCTestCase {
    var deepLinkManager: DeepLinkManager!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        deepLinkManager = DeepLinkManager()
        
        let schema = Schema([CardItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDownWithError() throws {
        deepLinkManager = nil
        modelContext = nil
        modelContainer = nil
    }
    
    func testHandleListDeepLink() throws {
        let url = URL(string: "cards://list")!
        
        deepLinkManager.handleDeepLink(url, modelContext: modelContext)
        
        XCTAssertNil(deepLinkManager.activeSheet)
        XCTAssertNil(deepLinkManager.selectedCardId)
    }
    
    func testHandleCameraDeepLink() throws {
        let url = URL(string: "cards://camera")!
        
        deepLinkManager.handleDeepLink(url, modelContext: modelContext)
        
        if case .camera = deepLinkManager.activeSheet {
            // Success
        } else {
            XCTFail("Expected camera sheet to be active")
        }
    }
    
    func testHandleAddDeepLink() throws {
        let url = URL(string: "cards://add")!
        
        deepLinkManager.handleDeepLink(url, modelContext: modelContext)
        
        if case .addCard = deepLinkManager.activeSheet {
            // Success
        } else {
            XCTFail("Expected addCard sheet to be active")
        }
    }
    
    func testHandleCardDeepLink() throws {
        // Create a test card
        let testCard = CardItem(timestamp: Date(), code: "123456", name: "Test Card")
        modelContext.insert(testCard)
        try modelContext.save()
        
        let url = URL(string: "cards://card/123456")!
        
        deepLinkManager.handleDeepLink(url, modelContext: modelContext)
        
        XCTAssertEqual(deepLinkManager.selectedCardId, "123456")
    }
    
    func testHandleEditDeepLink() throws {
        // Create a test card
        let testCard = CardItem(timestamp: Date(), code: "123456", name: "Test Card")
        modelContext.insert(testCard)
        try modelContext.save()
        
        let url = URL(string: "cards://edit/123456")!
        
        deepLinkManager.handleDeepLink(url, modelContext: modelContext)
        
        if case .editCard(let card) = deepLinkManager.activeSheet {
            XCTAssertEqual(card.code, testCard.code)
        } else {
            XCTFail("Expected editCard sheet to be active")
        }
    }
    
    func testHandleInvalidScheme() throws {
        let url = URL(string: "invalid://camera")!
        
        deepLinkManager.handleDeepLink(url, modelContext: modelContext)
        
        XCTAssertNil(deepLinkManager.activeSheet)
        XCTAssertNil(deepLinkManager.selectedCardId)
    }
    
    func testHandleEditWithInvalidCardId() throws {
        let url = URL(string: "cards://edit/invalid-id")!
        
        deepLinkManager.handleDeepLink(url, modelContext: modelContext)
        
        XCTAssertNil(deepLinkManager.activeSheet)
    }
    
    func testHandleEditWithCardCode() throws {
        // Create a test card
        let testCard = CardItem(timestamp: Date(), code: "123456", name: "Test Card")
        modelContext.insert(testCard)
        try modelContext.save()
        
        let url = URL(string: "cards://edit/123456")!
        
        deepLinkManager.handleDeepLink(url, modelContext: modelContext)
        
        if case .editCard(let card) = deepLinkManager.activeSheet {
            XCTAssertEqual(card.code, testCard.code)
        } else {
            XCTFail("Expected editCard sheet to be active")
        }
    }
}
