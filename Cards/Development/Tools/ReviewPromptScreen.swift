import StoreKit
import SwiftUI

/// Development > Review Prompt (DEV-3): what the review prompt has counted, and
/// buttons to ask for a rating now, to make it due on the next return from a
/// card, and to start again. StoreKit shows its prompt on every request in a
/// debug build, so this is how its look and the rule can be checked.
struct ReviewPromptScreen: View {
    @AppStorage(DeviceSettings.reviewPromptKey) private var reviewPrompt = ReviewPrompt()
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityAnnouncer) private var announcer
    @State private var status: String?

    /// The same version the Cards tab counts for.
    private let version = Bundle.main.marketingVersion ?? ""

    var body: some View {
        List {
            Section {
                row("Version Counted", value: reviewPrompt.version.isEmpty ? "None" : reviewPrompt.version)
                row("Days With a Card Shown", value: "\(reviewPrompt.daysShown) of \(ReviewPrompt.daysNeeded)")
                row("Last Card Shown", value: reviewPrompt.lastShown?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                row("Asked in This Version", value: reviewPrompt.asked ? "Yes" : "No")
                row("Due", value: reviewPrompt.isDue(in: version) ? "Yes" : "No")
            } header: {
                Text(verbatim: "Counted")
                    .foregroundColor(.secondaryText)
            } footer: {
                Text(Self.ruleFooter)
                    .foregroundColor(.secondaryText)
            }

            Section {
                Button(String("Ask for a Rating Now")) {
                    requestReview()
                    report("Asked for a rating.")
                }
                .accessibilityIdentifier("askForRatingNowButton")

                Button(String("Make It Due")) {
                    reviewPrompt = ReviewPrompt(version: version, daysShown: ReviewPrompt.daysNeeded, lastShown: .now)
                    report("The app asks the next time you come back from a card to the list.")
                }
                .accessibilityIdentifier("makeReviewPromptDueButton")

                Button(String("Start Again"), role: .destructive) {
                    reviewPrompt = ReviewPrompt()
                    report("The review prompt has counted nothing.")
                }
                .accessibilityIdentifier("resetReviewPromptButton")
            } footer: {
                Text(status ?? Self.actionsFooter)
                    .foregroundColor(.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.primaryBackground)
        .navigationTitle(Text(verbatim: "Review Prompt"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A label and its value, shown as written: development copy stays out of the catalogue.
    private func row(_ title: String, value: String) -> some View {
        LabeledContent {
            Text(verbatim: value)
        } label: {
            Text(verbatim: title)
        }
    }

    private static let ruleFooter = """
        The app asks on coming back from a card to the list, once a card has been shown on \(ReviewPrompt.daysNeeded) days \
        in this version, and only once a version.
        """
    private static let actionsFooter = """
        Apple shows its prompt on every request in a debug build, at most three times a year in an App Store build, \
        and never in TestFlight. Ask for a Rating Now leaves the counts as they are.
        """

    private func report(_ message: String) {
        status = message
        announcer.announce(message)
    }
}
