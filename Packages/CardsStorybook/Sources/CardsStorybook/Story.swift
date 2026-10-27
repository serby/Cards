import SwiftUI

/// One tunable parameter exposed in a story's controls panel.
public struct StoryKnob: Identifiable {
    public enum Kind {
        case toggle(Bool)
        case text(String)
        /// Default, permitted range, and step.
        case number(Double, ClosedRange<Double>, Double)
        /// Choices, and the one selected by default.
        case options([String], String)
    }

    public let name: String
    public let kind: Kind

    public var id: String { name }

    public init(name: String, kind: Kind) {
        self.name = name
        self.kind = kind
    }

    public static func toggle(_ name: String, _ value: Bool) -> Self {
        Self(name: name, kind: .toggle(value))
    }

    public static func text(_ name: String, _ value: String) -> Self {
        Self(name: name, kind: .text(value))
    }

    public static func number(
        _ name: String,
        _ value: Double,
        in range: ClosedRange<Double>,
        step: Double = 1
    ) -> Self {
        Self(name: name, kind: .number(value, range, step))
    }

    public static func options(_ name: String, _ choices: [String], _ selected: String) -> Self {
        Self(name: name, kind: .options(choices, selected))
    }
}

/// Live knob values for the story on screen. Stories read from it; the controls
/// panel writes to it.
@MainActor
@Observable
public final class KnobValues {
    private var bools: [String: Bool] = [:]
    private var strings: [String: String] = [:]
    private var numbers: [String: Double] = [:]
    private var selections: [String: String] = [:]

    public init(_ knobs: [StoryKnob]) {
        reset(to: knobs)
    }

    public func reset(to knobs: [StoryKnob]) {
        bools.removeAll()
        strings.removeAll()
        numbers.removeAll()
        selections.removeAll()

        for knob in knobs {
            switch knob.kind {
            case .toggle(let value):
                bools[knob.name] = value
            case .text(let value):
                strings[knob.name] = value
            case .number(let value, _, _):
                numbers[knob.name] = value
            case .options(_, let selected):
                selections[knob.name] = selected
            }
        }
    }

    public func bool(_ name: String) -> Bool { bools[name] ?? false }
    public func string(_ name: String) -> String { strings[name] ?? "" }
    public func number(_ name: String) -> Double { numbers[name] ?? 0 }
    public func option(_ name: String) -> String { selections[name] ?? "" }

    public func integer(_ name: String) -> Int { Int(number(name).rounded()) }

    public func set(_ value: Bool, for name: String) { bools[name] = value }
    public func set(_ value: String, for name: String) { strings[name] = value }
    public func set(_ value: Double, for name: String) { numbers[name] = value }
    public func select(_ value: String, for name: String) { selections[name] = value }

    public func boolBinding(_ name: String) -> Binding<Bool> {
        Binding(get: { self.bool(name) }, set: { self.set($0, for: name) })
    }

    public func stringBinding(_ name: String) -> Binding<String> {
        Binding(get: { self.string(name) }, set: { self.set($0, for: name) })
    }

    public func numberBinding(_ name: String) -> Binding<Double> {
        Binding(get: { self.number(name) }, set: { self.set($0, for: name) })
    }

    public func optionBinding(_ name: String) -> Binding<String> {
        Binding(get: { self.option(name) }, set: { self.select($0, for: name) })
    }
}

/// A single entry in the storybook: one knob-driven rendering, plus any number
/// of fixed variants to eyeball side by side.
@MainActor
public struct Story: Identifiable {
    public let id: String
    public let title: String
    public let section: String
    public let knobs: [StoryKnob]
    public let interactive: @MainActor (KnobValues) -> AnyView
    public let gallery: [(name: String, view: AnyView)]

    public init(
        id: String,
        title: String,
        section: String,
        knobs: [StoryKnob] = [],
        gallery: [(name: String, view: AnyView)] = [],
        interactive: @escaping @MainActor (KnobValues) -> AnyView
    ) {
        self.id = id
        self.title = title
        self.section = section
        self.knobs = knobs
        self.gallery = gallery
        self.interactive = interactive
    }
}
