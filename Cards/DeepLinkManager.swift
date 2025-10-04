import SwiftUI
import SwiftData

class DeepLinkManager: ObservableObject {
    @Published var activeSheet: ActiveSheet?
    @Published var selectedCardId: String?
    
    enum ActiveSheet: Identifiable {
        case camera
        case addCard
        case editCard(CardItem)
        
        var id: String {
            switch self {
            case .camera: return "camera"
            case .addCard: return "addCard"
            case .editCard(let item): return "editCard-\(item.id)"
            }
        }
    }
    
    func handleDeepLink(_ url: URL, modelContext: ModelContext) {
        guard url.scheme == "cards" else { return }
        
        let path = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        switch path {
        case "list":
            // Already on list - no action needed
            break
        case "camera":
            activeSheet = .camera
        case "add":
            activeSheet = .addCard
        case "card":
            if let cardId = pathComponents.first {
                selectedCardId = cardId
            }
        case "edit":
            if let cardId = pathComponents.first,
               let card = findCard(by: cardId, in: modelContext) {
                activeSheet = .editCard(card)
            }
        default:
            break
        }
    }
    
    private func findCard(by id: String, in modelContext: ModelContext) -> CardItem? {
        let descriptor = FetchDescriptor<CardItem>()
        do {
            let cards: [CardItem] = try modelContext.fetch(descriptor)
            for card in cards {
                if card.code == id {
                    return card
                }
            }
            return nil
        } catch {
            return nil
        }
    }
}
