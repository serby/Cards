import SwiftUI

/// The Development tab's tools, with stand-in effects so a story never
/// changes the app's settings or closes it.
@MainActor
let developmentStories: [Story] = [
    languageStory
]

private enum LanguageKnob {
    static let current = "Current language"
}

/// The Language tool (DEV-4), pushed as the Development tab pushes it, with
/// `client` in place of the app's own override.
@MainActor
private func languageScreen(_ client: AppLanguageClient) -> AnyView {
    AnyView(
        NavigationStack {
            LanguageScreen()
        }
        .environment(\.appLanguageClient, client)
    )
}

/// The knob is the override: choosing a language and Close Card Barcodes moves
/// the tick and the knob together, and nothing quits.
@MainActor
private let languageStory: Story = {
    let choices = LanguageChoice.all()
    let german = choices.first { $0.language?.id == "de" } ?? .system
    return Story(
        id: "development-language",
        title: "LanguageScreen",
        section: "Development",
        galleryLayout: .oneAtATime,
        knobs: [
            .options(LanguageKnob.current, choices.map(\.name), LanguageChoice.system.name)
        ],
        gallery: [
            (name: "System", view: languageScreen(.simulated(LanguageOverrideBox()))),
            (name: german.name, view: languageScreen(.simulated(LanguageOverrideBox(override: german.override))))
        ]
    ) { knobs in
        languageScreen(
            AppLanguageClient(
                override: {
                    let name = knobs.option(LanguageKnob.current)
                    return choices.first { $0.name == name }?.override ?? []
                },
                setOverride: { override in
                    knobs.select(LanguageChoice.current(for: override, in: choices).name, for: LanguageKnob.current)
                },
                quit: {}
            )
        )
    }
}()
