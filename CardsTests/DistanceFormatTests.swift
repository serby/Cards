@testable import Cards
import CoreLocation
import Foundation
import Testing

/// How distances and radii are written in each Distances choice (SET-4,
/// PLACE-3, PLACE-6).
struct DistanceFormatTests {
    private static let uk = Locale(identifier: "en_GB")
    private static let us = Locale(identifier: "en_US")
    /// UK English with Metric chosen in Language & Region.
    private static let metric = Locale(identifier: "en_GB@measure=metric")
    private static let germany = Locale(identifier: "de_DE")

    private func format(_ units: DistanceUnits, _ locale: Locale = uk) -> DistanceFormat {
        DistanceFormat(units: units, locale: locale)
    }

    @Test(arguments: [
        (5.0, "5 m"), (12, "10 m"), (120, "120 m"), (350, "350 m"), (512, "500 m"),
        (1_200, "1.2 km"), (4_200, "4.2 km"), (25_000, "25 km"), (123_456, "123 km")
    ])
    func kilometres(_ metres: CLLocationDistance, _ text: String) {
        #expect(format(.kilometres).distance(metres) == text)
        // Wherever you are.
        #expect(format(.kilometres, Self.us).distance(metres) == text)
    }

    @Test(arguments: [
        (5.0, "5 yd"), (12, "10 yd"), (120, "150 yd"), (350, "400 yd"), (512, "550 yd"),
        (1_200, "0.75 mi"), (4_200, "2.6 mi"), (25_000, "16 mi"), (123_456, "77 mi")
    ])
    func miles(_ metres: CLLocationDistance, _ text: String) {
        #expect(format(.miles).distance(metres) == text)
        // Wherever you are, in yards rather than the US's feet.
        #expect(format(.miles, Self.us).distance(metres) == text)
        #expect(format(.miles, Self.metric).distance(metres) == text)
    }

    @Test func numbersAreWrittenForTheLocale() {
        #expect(format(.kilometres, Self.germany).distance(1_200) == "1,2 km")
        #expect(format(.miles, Self.germany).distance(1_200) == "0,75 mi")
        #expect(format(.miles).distance(1_005) == "0.62 mi")
    }

    @Test func automaticFollowsTheMeasurementSystem() {
        #expect(format(.automatic, Self.metric).distance(350) == "350 m")
        #expect(format(.automatic, Self.metric).distance(1_200) == "1.2 km")
        #expect(format(.automatic, Self.germany).distance(1_200) == "1,2 km")
        #expect(format(.automatic, Self.uk).distance(350) == "400 yd")
        #expect(format(.automatic, Self.uk).distance(1_200) == "0.75 mi")
        // The US writes short road distances in feet.
        #expect(format(.automatic, Self.us).distance(350) == "1,150 ft")
        #expect(format(.automatic, Self.us).distance(1_200) == "0.75 mi")
    }

    /// Automatic writes distances as iOS's road style does, as the app did
    /// before there was a choice.
    @Test(arguments: ["en_GB", "en_US", "en_GB@measure=metric", "de_DE"].map(Locale.init(identifier:)))
    func automaticMatchesRoadDistances(_ locale: Locale) {
        for metres in [3.0, 12, 37, 120, 299, 350, 512, 800, 1_234, 4_200, 9_876, 25_000, 123_456] {
            let road = Measurement(value: metres, unit: UnitLength.meters)
                .formatted(.measurement(width: .abbreviated, usage: .road).locale(locale))
            #expect(format(.automatic, locale).distance(metres) == road, "\(metres) m in \(locale.identifier)")
        }
    }

    @Test func automaticMeansKilometresOrMiles() {
        #expect(DistanceUnits.automatic.resolved(for: Self.metric) == .kilometres)
        #expect(DistanceUnits.automatic.resolved(for: Self.germany) == .kilometres)
        #expect(DistanceUnits.automatic.resolved(for: Self.uk) == .miles)
        #expect(DistanceUnits.automatic.resolved(for: Self.us) == .miles)
        #expect(DistanceUnits.kilometres.resolved(for: Self.uk) == .kilometres)
        #expect(DistanceUnits.miles.resolved(for: Self.germany) == .miles)
    }

    @Test func settingsSaysWhatAutomaticMeans() {
        #expect(DistanceUnits.automatic.title(for: Self.metric) == "Automatic (Kilometres)")
        #expect(DistanceUnits.automatic.title(for: Self.uk) == "Automatic (Miles)")
        #expect(DistanceUnits.automatic.title(for: Self.us) == "Automatic (Miles)")
        #expect(DistanceUnits.kilometres.title(for: Self.uk) == "Kilometres")
        #expect(DistanceUnits.miles.title(for: Self.metric) == "Miles")
    }

    @Test func wideWidthSpellsTheUnitsOut() {
        #expect(format(.kilometres).distance(350, width: .wide) == "350 metres")
        #expect(format(.kilometres).distance(4_200, width: .wide) == "4.2 kilometres")
        #expect(format(.miles).distance(350, width: .wide) == "400 yards")
        #expect(format(.miles).distance(4_200, width: .wide) == "2.6 miles")
        #expect(format(.automatic, Self.us).distance(350, width: .wide) == "1,150 feet")
    }

    @Test func hereAndThePlace() {
        let here = CardProximity(placeName: "Boulder Barn", distance: 0)
        let near = CardProximity(placeName: "Boulder Barn", distance: 350)
        for units in DistanceUnits.allCases {
            #expect(here.text(showsPlace: false, in: format(units)) == "Here")
            #expect(here.text(showsPlace: true, in: format(units)) == "At Boulder Barn")
            #expect(here.spokenDescription(in: format(units)) == "You're at Boulder Barn")
        }
        #expect(near.text(showsPlace: false, in: format(.kilometres)) == "350 m")
        #expect(near.text(showsPlace: true, in: format(.kilometres)) == "350 m · Boulder Barn")
        #expect(near.text(showsPlace: true, in: format(.miles)) == "400 yd · Boulder Barn")
    }

    @Test func voiceOverSaysTheDistanceInTheChosenUnits() {
        let near = CardProximity(placeName: "Local Roast Portobello", distance: 350)
        #expect(near.spokenDescription(in: format(.kilometres)) == "350 metres from Local Roast Portobello")
        #expect(near.spokenDescription(in: format(.miles)) == "400 yards from Local Roast Portobello")
        #expect(near.spokenDescription(in: format(.automatic, Self.us)) == "1,150 feet from Local Roast Portobello")
    }

    @Test func radiusIsInMetresOrYards() {
        #expect(format(.kilometres).radius(200) == "200 m")
        #expect(format(.kilometres).radius(1_000) == "1,000 m")
        #expect(format(.miles).radius(200) == "220 yd")
        #expect(format(.miles).radius(1_000) == "1,095 yd")
        #expect(format(.automatic, Self.metric).radius(200) == "200 m")
        #expect(format(.automatic, Self.uk).radius(200) == "220 yd")
        #expect(format(.automatic, Self.us).radius(200) == "220 yd")
        #expect(format(.kilometres).radius(200, width: .wide) == "200 metres")
        #expect(format(.miles).radius(200, width: .wide) == "220 yards")
    }

    /// A radius set in yards and shown in metres is rounded to the nearest 5.
    @Test func radiusIsRoundedToTheNearestFive() {
        #expect(format(.kilometres).radius(RadiusScale.yards.metres(250)) == "230 m")
        #expect(format(.miles).radius(RadiusScale.yards.metres(250)) == "250 yd")
    }

    @Test func radiusSliderStepsInTheShownUnit() {
        #expect(format(.kilometres).radiusScale == .metres)
        #expect(format(.automatic, Self.metric).radiusScale == .metres)
        #expect(format(.miles).radiusScale == .yards)
        #expect(format(.automatic, Self.us).radiusScale == .yards)

        #expect(RadiusScale.metres.range == 50...1_000)
        #expect(RadiusScale.metres.step == 25)
        #expect(RadiusScale.yards.range == 50...1_100)
        #expect(RadiusScale.yards.step == 25)
        #expect(RadiusScale.metres.unit == .meters)
        #expect(RadiusScale.yards.unit == .yards)
    }

    @Test func radiusStaysInMetres() {
        #expect(RadiusScale.metres.metres(200) == 200)
        #expect(abs(RadiusScale.yards.metres(100) - 91.44) < 0.0001)
        #expect(abs(RadiusScale.yards.value(ofMetres: 91.44) - 100) < 0.0001)
        #expect(abs(RadiusScale.yards.metres(RadiusScale.yards.value(ofMetres: 200)) - 200) < 0.0001)
    }

    @Test func choiceIsStoredByItsRawValue() {
        #expect(DeviceSettings.distanceUnitsKey == "distanceUnits")
        #expect(DistanceUnits.allCases.map(\.rawValue) == ["automatic", "kilometres", "miles"])
        #expect(DistanceUnits.stored("miles") == .miles)
        #expect(DistanceUnits.stored("leagues") == .automatic)
        #expect(DistanceUnits.stored(nil) == .automatic)
    }
}
