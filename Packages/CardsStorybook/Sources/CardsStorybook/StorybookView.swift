import CardsUI
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
            .navigationTitle("Storybook")
        } detail: {
            if let story = stories.first(where: { $0.id == selection }) {
                StoryStage(story: story, display: display)
                    .id(story.id)
            } else {
                ContentUnavailableView(
                    "Select a story",
                    systemImage: "square.grid.2x2",
                    description: Text("Every CardsUI view, with live parameters.")
                )
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

    init(story: Story, display: DisplayOptions) {
        self.story = story
        self.display = display
        _knobs = State(initialValue: KnobValues(story.knobs))
    }

    private var modes: [StoryMode] {
        story.gallery.isEmpty ? [.interactive] : StoryMode.allCases
    }

    var body: some View {
        VStack(spacing: 0) {
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.screenBrightness, .simulated(brightness))
                .environment(\.accessibilityAnnouncer, .silent)
                .environment(\.layoutDirection, display.layoutDirection)
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
                    Picker("Mode", selection: $mode) {
                        ForEach(modes) { Text($0.rawValue).tag($0) }
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

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 0) {
            if mode == .interactive, !story.knobs.isEmpty {
                Form {
                    Section("Parameters") {
                        ForEach(story.knobs) { KnobRow(knob: $0, knobs: knobs) }
                    }
                }
                .frame(maxHeight: 260)
            }

            HStack {
                Label(
                    "Simulated brightness \(brightness.level, format: .number.precision(.fractionLength(2)))",
                    systemImage: "sun.max"
                )
                Spacer()
                Button("Reset") {
                    knobs.reset(to: story.knobs)
                    brightness.level = 0.5
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

    var body: some View {
        Menu {
            Picker("Appearance", selection: Binding(
                get: { display.colourScheme },
                set: { display.colourScheme = $0 }
            )) {
                ForEach(ColourSchemeChoice.allCases) { Text($0.rawValue).tag($0) }
            }

            Picker("Text size", selection: Binding(
                get: { display.typeSize },
                set: { display.typeSize = $0 }
            )) {
                ForEach(DisplayOptions.typeSizes, id: \.self) { Text($0.label).tag($0) }
            }

            Toggle("Right to left", isOn: Binding(
                get: { display.rightToLeft },
                set: { display.rightToLeft = $0 }
            ))
        } label: {
            Image(systemName: "slider.horizontal.3")
                .accessibilityLabel("Display options")
        }
    }
}
