import SwiftUI

/// What a place search has found, under the location picker's search field:
/// a list of suggestions, each its title over its subtitle, or a few words
/// when there are none (PLACE-2).
public struct PlaceSearchResults: View {
    private let status: PlaceSearchStatus
    private let onChoose: (PlaceSuggestion) -> Void
    /// The list's own height, so a short list takes only the room it needs.
    @State private var listHeight: CGFloat = 0

    /// The most the list takes before it scrolls: about four suggestions, which
    /// leaves the search field and the map in view above the keyboard.
    private static let maxListHeight: CGFloat = 240

    public init(status: PlaceSearchStatus, onChoose: @escaping (PlaceSuggestion) -> Void = { _ in }) {
        self.status = status
        self.onChoose = onChoose
    }

    public var body: some View {
        switch status {
        case .found(let suggestions):
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        if suggestion != suggestions.first {
                            Divider()
                        }
                        row(suggestion)
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            // Scrolling the list puts the keyboard away, so the whole list can be seen.
            .scrollDismissesKeyboard(.immediately)
            .frame(height: min(listHeight, Self.maxListHeight))
            .accessibilityIdentifier("placeSuggestions")
        case .searching:
            HStack(spacing: 10) {
                ProgressView()
                message
            }
            .accessibilityElement(children: .combine)
        case .notFound, .failed:
            message
        }
    }

    @ViewBuilder
    private var message: some View {
        if let message = status.message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("placeSearchMessage")
        }
    }

    private func row(_ suggestion: PlaceSuggestion) -> some View {
        Button {
            onChoose(suggestion)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .foregroundStyle(.primary)
                if !suggestion.subtitle.isEmpty {
                    Text(suggestion.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(
            Text(
                "Shows this place on the map",
                comment: "VoiceOver hint for a place suggested under the search field on the Add Location and Edit Location map."
            )
        )
        .accessibilityIdentifier("placeSuggestion_\(suggestion.title)")
    }
}

#if DEBUG
#Preview("Suggestions") {
    PlaceSearchResults(status: .found(PlaceSuggestion.samples(for: "Joe")))
        .padding()
}

#Preview("No place found") {
    PlaceSearchResults(status: .notFound("Corner Grocer"))
        .padding()
}

#Preview("Offline") {
    PlaceSearchResults(status: .failed(.offline))
        .padding()
}
#endif
