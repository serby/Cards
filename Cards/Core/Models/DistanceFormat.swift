import CoreLocation
import Foundation

/// How the app writes distances and radii: in the units chosen in Settings
/// (SET-4), with numbers written for `locale`, which also says what Automatic
/// means. Pure, so every rule here is tested directly.
public struct DistanceFormat: Hashable, Sendable {
    public var units: DistanceUnits
    public var locale: Locale

    public init(units: DistanceUnits, locale: Locale) {
        self.units = units
        self.locale = locale
    }

    /// A distance to somewhere, rounded as road distances are (PLACE-6): "350 m"
    /// and "1.2 km", or "400 yd" and "0.75 mi". With Automatic in the US, short
    /// distances are in feet, "1,150 ft", as the system writes them.
    public func distance(_ metres: CLLocationDistance) -> String {
        formatted(road.measurement(of: metres))
    }

    /// A place's radius, to the nearest 5 metres or 5 yards (PLACE-3): "200 m",
    /// or "220 yd" for the same radius in yards.
    public func radius(_ metres: CLLocationDistance) -> String {
        let scale = radiusScale
        let value = (scale.value(ofMetres: metres) / 5).rounded() * 5
        return formatted(Measurement(value: value, unit: scale.unit))
    }

    /// The radius slider's scale, in the unit the radius is shown in (PLACE-3).
    public var radiusScale: RadiusScale {
        units.resolved(for: locale) == .miles ? .yards : .metres
    }

    /// Which road units this choice writes distances in.
    private var road: RoadUnits {
        switch units {
        case .kilometres:
            return .metric
        case .miles:
            return .imperial
        case .automatic:
            switch locale.measurementSystem {
            case .us:
                return .us
            case .uk:
                return .imperial
            default:
                return .metric
            }
        }
    }

    private func formatted(_ measurement: Measurement<UnitLength>) -> String {
        measurement.formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...2)))
                .locale(locale)
        )
    }
}

/// The radius slider in the unit the radius is shown in: metres from 50 to
/// 1,000, or yards from 50 to 1,100, in steps of 25 either way (PLACE-3). A
/// place's radius is kept in metres whichever it is.
public struct RadiusScale: Hashable, Sendable {
    public let range: ClosedRange<Double>
    public let step: Double
    private let metresPerUnit: Double

    public static let metres = Self(range: CardLocation.radiusRange, step: 25, metresPerUnit: 1)
    public static let yards = Self(range: 50...1_100, step: 25, metresPerUnit: 0.9144)

    /// The unit the slider's values are in.
    public var unit: UnitLength {
        metresPerUnit == 1 ? .meters : .yards
    }

    /// A radius in metres as a value on this scale.
    public func value(ofMetres metres: CLLocationDistance) -> Double {
        metres / metresPerUnit
    }

    /// A value on this scale as a radius in metres.
    public func metres(_ value: Double) -> CLLocationDistance {
        value * metresPerUnit
    }
}

/// The units and rounding of road distances in each measurement system, as
/// Foundation's `.road` usage writes them for a metric country, the UK and the
/// US. Done here, rather than with `.road`, so that Kilometres and Miles can be
/// chosen wherever you are while numbers stay in your own locale's style.
private enum RoadUnits {
    /// Kilometres from 900 m, and metres below.
    case metric
    /// Miles from half a mile, and yards below.
    case imperial
    /// Miles from half a mile, and feet below.
    case us

    private static let metresPerMile = 1_609.344

    func measurement(of metres: CLLocationDistance) -> Measurement<UnitLength> {
        let miles = metres / Self.metresPerMile
        switch self {
        case .metric:
            if metres >= 900 {
                return Measurement(value: Self.whole(metres / 1_000), unit: .kilometers)
            }
            return Measurement(value: Self.short(metres, fiftiesFrom: 300), unit: .meters)
        case .imperial:
            if miles >= 0.5 {
                return Measurement(value: Self.whole(miles), unit: .miles)
            }
            return Measurement(value: Self.short(metres / 0.9144, fiftiesFrom: 100), unit: .yards)
        case .us:
            if miles >= 0.5 {
                return Measurement(value: Self.whole(miles), unit: .miles)
            }
            return Measurement(value: Self.short(metres / 0.3048, fiftiesFrom: 100), unit: .feet)
        }
    }

    /// A short distance to the nearest 50 from `fiftiesFrom`, to the nearest 10
    /// from 10, and to the nearest 1 below that: "350 m", "40 yd", "5 ft".
    private static func short(_ value: Double, fiftiesFrom: Double) -> Double {
        let increment: Double = value >= fiftiesFrom ? 50 : value >= 10 ? 10 : 1
        return nearest(value, increment)
    }

    /// Rounded to a whole number, or to two significant digits below 10: "16",
    /// "2.6", "0.75".
    private static func whole(_ value: Double) -> Double {
        guard value > 0, value < 10 else { return value.rounded(.toNearestOrEven) }
        let factor = pow(10, 1 - floor(log10(value)))
        return (value * factor).rounded(.toNearestOrEven) / factor
    }

    private static func nearest(_ value: Double, _ increment: Double) -> Double {
        (value / increment).rounded(.toNearestOrEven) * increment
    }
}
