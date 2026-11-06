import SwiftUI

/// The Development tab (DEV-1): the tools for building and testing the app.
/// Debug builds only; `DevelopmentHooks.tabs` shows it.
struct DevelopmentView: View {
    @State private var showsStorybook = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showsStorybook = true
                    } label: {
                        ToolRow(title: "Storybook", detail: "Every view, with live parameters.", systemImage: "square.grid.2x2")
                    }
                    .accessibilityIdentifier("storybookTool")

                    NavigationLink {
                        TestNotificationScreen()
                    } label: {
                        ToolRow(
                            title: "Test Notification",
                            detail: "A card's arrival notification, in \(Int(TestArrival.delay)) seconds.",
                            systemImage: "bell.badge"
                        )
                    }
                    .accessibilityIdentifier("testNotificationTool")

                    NavigationLink {
                        ReviewPromptScreen()
                    } label: {
                        ToolRow(
                            title: "Review Prompt",
                            detail: "When the app asks for a rating, and asking now.",
                            systemImage: "star.bubble"
                        )
                    }
                    .accessibilityIdentifier("reviewPromptTool")
                } header: {
                    Text("Tools")
                        .foregroundColor(.secondaryText)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.primaryBackground)
            .navigationTitle("Development")
            // Full screen, as the Storybook is a split view and cannot be pushed.
            .fullScreenCover(isPresented: $showsStorybook) {
                StorybookView(onDone: { showsStorybook = false })
            }
        }
    }
}

/// A tool's name and what it does, with its symbol.
private struct ToolRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.primaryText)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundColor(.accent)
                .accessibilityHidden(true)
        }
    }
}
