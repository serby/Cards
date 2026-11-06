import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// What the card screen's share menu sends, made ready by its connector: a
/// link to add the card (SHARE-1) and a picture of it (SHARE-2).
public struct CardShare: Sendable {
    public let link: URL
    public let image: CardImage

    public init(link: URL, image: CardImage) {
        self.link = link
        self.image = image
    }
}

/// A PNG of a card face. It is drawn only when the share sheet asks for it, so
/// opening a card draws nothing extra.
public struct CardImage: Transferable, Sendable {
    /// The name the share sheet gives the file, such as "Boots Advantage.png".
    public let fileName: String
    private let draw: @MainActor @Sendable () -> Data?

    public init(cardName: String, draw: @escaping @MainActor @Sendable () -> Data?) {
        fileName = Self.fileName(for: cardName)
        self.draw = draw
    }

    /// "<Card name>.png", with the characters a file name can't hold replaced,
    /// or "Card.png" for a card without a name.
    public static func fileName(for cardName: String) -> String {
        let name = cardName
            .components(separatedBy: CharacterSet(charactersIn: "/\\:").union(.newlines).union(.controlCharacters))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ".")))
        return (name.isEmpty ? "Card" : name) + ".png"
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in
            guard let png = await image.draw() else { throw NotDrawn() }
            return png
        }
        .suggestedFileName { $0.fileName }
    }

    private struct NotDrawn: Error {}
}
