import SwiftUI

/// Browser for every pure `CardsUI` view: pick a story on the left, tune it on
/// the right. Runs with no store and no camera.
@MainActor
public struct StorybookView: View {
    private let stories: [Story]
    @State private var selection: Story.ID?
    @State private var display = DisplayOptions()
    // Keeps the story list alongside the stage on iPad instead of collapsing to
    // an empty detail pane. Ignored in compact widths, where iPhone shows the
    // list first and pushes the stage.
    @State private var columns = NavigationSplitViewVisibility.all

    public init() {
        self.stories = Story.all
    }

    public init(stories: [Story]) {
        self.stories = stories
    }

    private var sections: [String] {
        var seen: [String] = []
        for story in stories where !seen.contains(story.section) {
            seen.append(story.section)
        }
        return seen
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $selection) {
                ForEach(sections, id: \.self) { section in
                    Section(section) {
                        ForEach(stories.filter { $0.section == section }) { story in
                            Text(story.title).tag(story.id)
                        }
                    }
                }
            }
            .navigationTitle(Text(verbatim: "Storybook"))
        } detail: {
            if let story = stories.first(where: { $0.id == selection }) {
                StoryStage(story: story, display: display)
                    .id(story.id)
            } else {
                ContentUnavailableView {
                    Label {
                        Text(verbatim: "Select a story")
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                            .accessibilityHidden(true)
                    }
                } description: {
                    Text(verbatim: "Every CardsUI view, with live parameters.")
                }
            }
        }
    }
}

private enum StoryMode: String, CaseIterable, Identifiable {
    case interactive = "Interactive"
    case gallery = "Gallery"

    var id: String { rawValue }
}

private struct StoryStage: View {
    let story: Story
    let display: DisplayOptions

    @State private var knobs: KnobValues
    @State private var brightness = BrightnessBox()
    @State private var mode: StoryMode = .interactive
    @State private var variant = 0
    // The Storybook's own, which System and Automatic keep.
    @Environment(\.locale) private var inheritedLocale
    @Environment(\.layoutDirection) private var inheritedDirection

    init(story: Story, display: DisplayOptions) {
        self.story = story
        self.display = display
        _knobs = State(initialValue: KnobValues(story.knobs))
    }

    private var modes: [StoryMode] {
        story.gallery.isEmpty ? [.interactive] : StoryMode.allCases
    }

    private var layoutDirection: LayoutDirection {
        display.layoutDirection(inherited: inheritedDirection)
    }

    var body: some View {
        VStack(spacing: 0) {
            stage
                // Changing the direction of a List already on screen leaves its
                // rows mirrored, glyphs and all (seen on iOS 18.1), so each
                // direction gets a fresh stage. Knobs, mode and variant live
                // here, outside it, and survive.
                .id(layoutDirection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.screenBrightness, .simulated(brightness))
                .environment(\.accessibilityAnnouncer, .silent)
                .environment(\.locale, display.locale(inherited: inheritedLocale))
                .environment(\.layoutDirection, layoutDirection)
                .dynamicTypeSize(display.typeSize)
                .preferredColorScheme(display.colourScheme.preferred)

            Divider()
            footer
        }
        .navigationTitle(story.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if modes.count > 1 {
                ToolbarItem(placement: .principal) {
                    Picker(selection: $mode) {
                        ForEach(modes) { Text($0.rawValue).tag($0) }
                    } label: {
                        Text(verbatim: "Mode")
                    }
                    .pickerStyle(.segmented)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                DisplayOptionsMenu(display: display)
            }
        }
    }

    @ViewBuilder
    private var stage: some View {
        switch mode {
        case .interactive:
            story.interactive(knobs)
        case .gallery where story.galleryLayout == .oneAtATime:
            singleVariant
        case .gallery:
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Array(story.gallery.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.name)
                                .font(.caption.weight(.semibold))
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                            item.view
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var singleVariant: some View {
        let index = min(variant, story.gallery.count - 1)
        return VStack(spacing: 0) {
            Picker(selection: $variant) {
                ForEach(story.gallery.indices, id: \.self) { Text(story.gallery[$0].name).tag($0) }
            } label: {
                Text(verbatim: "Variant")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(.bar)
            Divider()
            story.gallery[index].view
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 0) {
            if mode == .interactive, !story.knobs.isEmpty {
                Form {
                    Section {
                        ForEach(story.knobs) { KnobRow(knob: $0, knobs: knobs) }
                    } header: {
                        Text(verbatim: "Parameters")
                    }
                }
                .frame(maxHeight: 260)
            }

            HStack {
                Label {
                    Text(verbatim: "Simulated brightness \(Double(brightness.level).formatted(.number.precision(.fractionLength(2))))")
                } icon: {
                    Image(systemName: "sun.max")
                        .accessibilityHidden(true)
                }
                Spacer()
                Button {
                    knobs.reset(to: story.knobs)
                    brightness.level = 0.5
                } label: {
                    Text(verbatim: "Reset")
                }
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}

private struct KnobRow: View {
    let knob: StoryKnob
    let knobs: KnobValues

    var body: some View {
        switch knob.kind {
        case .toggle:
            Toggle(knob.name, isOn: knobs.boolBinding(knob.name))
        case .text:
            HStack {
                Text(knob.name)
                Spacer()
                TextField(knob.name, text: knobs.stringBinding(knob.name))
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        case let .number(_, range, step):
            VStack(alignment: .leading) {
                HStack {
                    Text(knob.name)
                    Spacer()
                    Text(knobs.number(knob.name), format: .number.precision(.fractionLength(0...2)))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: knobs.numberBinding(knob.name), in: range, step: step)
            }
        case .options(let choices, _):
            Picker(knob.name, selection: knobs.optionBinding(knob.name)) {
                ForEach(choices, id: \.self) { Text($0).tag($0) }
            }
        }
    }
}

private struct DisplayOptionsMenu: View {
    let display: DisplayOptions
    @Environment(\.layoutDirection) private var inheritedDirection

    // One submenu per option, each showing its current value, so the top level
    // stays four rows: at the accessibility text sizes the options listed
    // inline ran off the screen.
    var body: some View {
        Menu {
            Picker(selection: Binding(
                get: { display.colourScheme },
                set: { display.colourScheme = $0 }
            )) {
                ForEach(ColourSchemeChoice.allCases) { Text(verbatim: $0.rawValue).tag($0) }
            } label: {
                optionLabel("Appearance", display.colourScheme.rawValue)
            }
            .pickerStyle(.menu)

            Picker(selection: Binding(
                get: { display.typeSize },
                set: { display.typeSize = $0 }
            )) {
                ForEach(DisplayOptions.typeSizes, id: \.self) { Text(verbatim: $0.label).tag($0) }
            } label: {
                optionLabel("Text size", display.typeSize.label)
            }
            .pickerStyle(.menu)

            Picker(selection: Binding(
                get: { display.language },
                set: { display.language = $0 }
            )) {
                Text(verbatim: "System").tag(StoryLanguage?.none)
                ForEach(display.languages) { language in
                    // VoiceOver reads the English name alone: a native name
                    // in another script, read in the Storybook's voice, is noise.
                    Text(verbatim: language.title)
                        .accessibilityLabel(Text(verbatim: language.englishName))
                        .tag(Optional(language))
                }
            } label: {
                optionLabel("Language", display.language?.englishName ?? "System")
            }
            .pickerStyle(.menu)

            Picker(selection: Binding(
                get: { display.direction },
                set: { display.direction = $0 }
            )) {
                ForEach(StoryDirection.allCases) { direction in
                    Text(verbatim: directionTitle(direction)).tag(direction)
                }
            } label: {
                optionLabel("Direction", directionTitle(display.direction))
            }
            .pickerStyle(.menu)
        } label: {
            Image(systemName: "slider.horizontal.3")
                .accessibilityLabel(Text(verbatim: "Display options"))
        }
    }

    /// A submenu's title with its current value beneath, as a menu subtitle.
    @ViewBuilder
    private func optionLabel(_ title: String, _ value: String) -> some View {
        Text(verbatim: title)
        Text(verbatim: value)
    }

    private func directionTitle(_ direction: StoryDirection) -> String {
        direction.title(for: display.language, inherited: inheritedDirection)
    }
}
