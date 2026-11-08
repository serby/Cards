import SwiftUI

public extension Story {
    /// Every story, in sidebar order. Add new entries to one of the lists below.
    static var all: [Self] {
        componentStories + screenStories + storeStories + developmentStories
    }
}

extension BarcodeType {
    static var allNames: [String] {
        allCases.map(\.rawValue)
    }

    static func named(_ raw: String) -> Self {
        Self(rawValue: raw) ?? .code128
    }
}

extension CardColor {
    /// The palette, then a custom colour, so knobs can show both kinds.
    static var allNames: [String] {
        allCases.map(\.rawValue) + [CardColor.custom(0x3399CC).rawValue]
    }

    static func named(_ raw: String) -> Self {
        stored(raw)
    }
}

/// Knobs for a card's distance to its nearest location, shared by every story
/// that shows one so they all read the same. They include the distance knobs.
enum ProximityKnobs {
    static let hasLocation = "Has location"
    static let place = "Place"
    static let distance = "Distance (m)"

    /// With `optional`, a "Has location" toggle decides whether there is one at all.
    static func knobs(optional: Bool = true, place: String = "Boulder Barn", distance: Double = 350) -> [StoryKnob] {
        (optional ? [.toggle(hasLocation, true)] : []) + [
            .text(Self.place, place),
            .number(Self.distance, distance, in: 0...10_000, step: 50)
        ] + DistanceKnobs.knobs
    }
}

extension KnobValues {
    /// The proximity the shared knobs describe; nil when "Has location" is off.
    func proximity(optional: Bool = true) -> CardProximity? {
        if optional && !bool(ProximityKnobs.hasLocation) { return nil }
        return CardProximity(placeName: string(ProximityKnobs.place), distance: number(ProximityKnobs.distance))
    }
}

/// Knobs for how distances and radii are written: the Distances choice in
/// Settings (SET-4), and the device's measurement system, which says what
/// Automatic means. Every story that shows a distance or a radius has them, and
/// applies them with `distances(_:)`.
enum DistanceKnobs {
    static let units = "Units"
    static let system = "Measurement system"

    /// The device's own system, or one of the three iOS offers.
    private static let systems: [(name: String, system: Locale.MeasurementSystem?)] = [
        ("Device", nil),
        ("Metric", .metric),
        ("UK", .uk),
        ("US", .us)
    ]

    static var knobs: [StoryKnob] {
        [
            .options(units, DistanceUnits.allCases.map(\.knobName), DistanceUnits.automatic.knobName),
            .options(system, systems.map(\.name), "Device")
        ]
    }

    static func system(named name: String) -> Locale.MeasurementSystem? {
        systems.first { $0.name == name }?.system
    }
}

extension DistanceUnits {
    /// "Automatic", "Kilometres" or "Miles", as the Units knob lists them.
    var knobName: String { rawValue.capitalized }

    static func named(_ name: String) -> Self {
        allCases.first { $0.knobName == name } ?? .automatic
    }
}

extension KnobValues {
    /// The Distances choice the Units knob describes.
    var distanceUnits: DistanceUnits {
        DistanceUnits.named(option(DistanceKnobs.units))
    }

    /// The Units knob as a binding, for the Settings picker.
    var distanceUnitsBinding: Binding<DistanceUnits> {
        Binding(get: { self.distanceUnits }, set: { self.select($0.knobName, for: DistanceKnobs.units) })
    }

    /// An options knob of raw values as a binding to the value it names, or
    /// `fallback` for one it doesn't.
    func optionBinding<Value: RawRepresentable<String>>(_ name: String, default fallback: Value) -> Binding<Value> {
        Binding(get: { Value(rawValue: self.string(name)) ?? fallback }, set: { self.select($0.rawValue, for: name) })
    }
}

extension View {
    /// Writes distances and radii as the Units and Measurement system knobs say.
    /// A gallery variant sets `\.distanceUnits` in the environment instead.
    @MainActor
    func distances(_ knobs: KnobValues) -> some View {
        modifier(DistanceKnobsModifier(units: knobs.distanceUnits, system: DistanceKnobs.system(named: knobs.option(DistanceKnobs.system))))
    }
}

/// Sets the distance units, and the measurement system on top of the
/// environment's own locale, so the language and number style stay as they are.
private struct DistanceKnobsModifier: ViewModifier {
    let units: DistanceUnits
    let system: Locale.MeasurementSystem?
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content
            .environment(\.distanceUnits, units)
            .environment(\.locale, system.map(locale.withMeasurementSystem) ?? locale)
    }
}

extension Locale {
    /// This locale with `system` as its measurement system.
    func withMeasurementSystem(_ system: MeasurementSystem) -> Locale {
        var components = Components(locale: self)
        components.measurementSystem = system
        return Locale(components: components)
    }
}

/// A representative code for each symbology, so the gallery shows real
/// barcodes rather than a wall of generation failures.
enum SampleCode {
    static func valid(for type: BarcodeType) -> String {
        switch type {
        case .code128:
            return "ABC-1234"
        case .code39:
            return "ABC1234"
        case .code93:
            return "ABC1234"
        case .ean8:
            return "96385074"
        case .ean13:
            return "5012345678900"
        case .upce:
            return "01234565"
        case .qrCode:
            return "https://serby.net"
        case .aztec:
            return "Cards"
        case .pdf417:
            return "Cards 1234"
        }
    }
}
