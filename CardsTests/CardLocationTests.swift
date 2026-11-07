@testable import Cards
import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import Testing

struct CardLocationTests {
    private let boulderBarn = CardLocation(name: "Boulder Barn", latitude: 51.5203, longitude: -0.2094, radius: 150)

    @Test func distanceIsZeroInsideTheCircle() {
        let inside = CLLocation(latitude: 51.5205, longitude: -0.2094)  // ~22 m from the centre
        #expect(boulderBarn.distance(from: inside) == 0)
    }

    @Test func distanceIsMeasuredToTheEdge() {
        let centre = CLLocation(latitude: boulderBarn.latitude, longitude: boulderBarn.longitude)
        let outside = CLLocation(latitude: 51.5303, longitude: -0.2094)  // ~1.1 km north
        let toCentre = outside.distance(from: centre)
        #expect(abs(boulderBarn.distance(from: outside) - (toCentre - 150)) < 0.001)
    }

    @Test func proximityPicksTheNearestLocation() throws {
        let far = CardLocation(name: "Wembley", latitude: 51.5560, longitude: -0.2796)
        let here = CLLocation(latitude: 51.5210, longitude: -0.2094)
        let proximity = try #require([far, boulderBarn].proximity(to: here))
        #expect(proximity.placeName == "Boulder Barn")
    }

    @Test func proximityNeedsALocationAndPlaces() {
        #expect([boulderBarn].proximity(to: nil) == nil)
        #expect([CardLocation]().proximity(to: CLLocation(latitude: 51.5, longitude: 0)) == nil)
    }

    @Test func proximityIsHereInsideTheCircle() throws {
        let proximity = try #require([boulderBarn].proximity(to: CLLocation(latitude: 51.5203, longitude: -0.2094)))
        #expect(proximity.isHere)
    }

    @Test @MainActor func locationsPersistThroughSwiftData() throws {
        let container = try ModelContainer(for: CardStore.schema, configurations: [CardStore.configuration(inMemory: true)])
        container.mainContext.insert(CardItem(code: "42", name: "Local Roast Coffee", locations: [boulderBarn]))
        try container.mainContext.save()

        let fetched = try ModelContext(container).fetch(FetchDescriptor<CardItem>())
        #expect(fetched.first?.locations == [boulderBarn])
    }

    @Test func exportRoundTripKeepsLocations() throws {
        let original = CardItem(code: "42", name: "Local Roast Coffee", locations: [boulderBarn])
        let data = try JSONEncoder().encode([CardItemDTO(from: original)])
        let imported = try JSONDecoder().decode([CardItemDTO].self, from: data)
        #expect(imported.first?.toCardItem().locations == [boulderBarn])
    }

    /// Automatic writes distances in each shipped language's own numbers and
    /// road units (SET-4): a decimal comma in Spain and Germany, a point in Japan.
    @Test func distancesUseTheLocalesNumbersAndRoadUnits() {
        func automatic(_ identifier: String) -> String {
            DistanceFormat(units: .automatic, locale: Locale(identifier: identifier)).distance(1_500)
        }
        #expect(automatic("de_DE").contains("1,5"), "German uses a decimal comma: \(automatic("de_DE"))")
        #expect(automatic("de_DE").hasSuffix("km"))
        #expect(automatic("es_ES").contains("1,5"), "Spanish uses a decimal comma: \(automatic("es_ES"))")
        #expect(automatic("es_ES").hasSuffix("km"))
        #expect(automatic("es_MX").contains("1.5"), "Mexican Spanish uses a decimal point: \(automatic("es_MX"))")
        #expect(automatic("ja_JP").contains("1.5"), "Japanese uses a decimal point: \(automatic("ja_JP"))")
        #expect(automatic("ja_JP").hasSuffix("km"))
        #expect(automatic("en_GB").contains("0.93"), "British English uses a decimal point: \(automatic("en_GB"))")
        #expect(automatic("en_GB").hasSuffix("mi"))
        #expect(automatic("ar_SA").contains("١٫٥"), "Saudi Arabic uses Arabic-Indic digits: \(automatic("ar_SA"))")
    }

    /// Kilometres and miles keep the language's numbers whatever the region's units.
    @Test(arguments: ["de_DE", "es_ES", "ja_JP"])
    func chosenUnitsKeepTheLanguagesNumbers(_ identifier: String) {
        let locale = Locale(identifier: identifier)
        #expect(DistanceFormat(units: .miles, locale: locale).distance(1_500).hasSuffix("mi"))
        #expect(DistanceFormat(units: .kilometres, locale: locale).radius(200).hasPrefix("200"))
        #expect(DistanceFormat(units: .miles, locale: locale).radius(200).hasSuffix("yd"))
    }

    /// VoiceOver hears units in words in every language, never abbreviations it might misread.
    @Test func spokenDistancesWriteTheUnitOut() {
        func spoken(_ identifier: String, _ units: DistanceUnits = .kilometres) -> String {
            DistanceFormat(units: units, locale: Locale(identifier: identifier)).distance(1_500, width: .wide)
        }
        #expect(DistanceFormat(units: .kilometres, locale: Locale(identifier: "en_GB")).radius(200, width: .wide) == "200 metres")
        #expect(spoken("de_DE").contains("Kilometer"), "\(spoken("de_DE"))")
        #expect(spoken("es_ES").contains("kilómetros"), "\(spoken("es_ES"))")
        #expect(spoken("ja_JP").contains("キロメートル"), "\(spoken("ja_JP"))")
        #expect(spoken("de_DE", .miles).contains("Meile"), "\(spoken("de_DE", .miles))")
    }

    /// Views take their distance format from the environment, so the
    /// Storybook's locale (and any `\.locale` set above them) reaches the number.
    @Test func viewsFormatDistancesInTheirLocale() {
        var environment = EnvironmentValues()
        environment.locale = Locale(identifier: "de_DE")
        environment.distanceUnits = .kilometres
        let german = DistanceFormat(units: .kilometres, locale: Locale(identifier: "de_DE"))
        #expect(environment.distanceFormat.distance(1_500) == german.distance(1_500))
        #expect(environment.distanceFormat.distance(1_500).contains("1,5"))
    }

    @Test func exportWithoutLocationsImportsWithNone() throws {
        let legacy = #"[{"code":"42","name":"Local Roast Coffee","order":0,"timestamp":0,"type":"EAN-13"}]"#
        let imported = try JSONDecoder().decode([CardItemDTO].self, from: Data(legacy.utf8))
        #expect(imported.first?.toCardItem().locations.isEmpty == true)
    }

    /// PLACE-8: a changed place takes the old one's spot and keeps its id, so its
    /// arrival reminder is replaced rather than joined by a second one.
    @Test func changingAPlaceInTheFormKeepsItsSpotAndId() {
        let pool = CardLocation(name: "Pool", latitude: 51.50, longitude: -0.20)
        var draft = CardDraft(name: "Gym", code: "1", locations: [boulderBarn, pool])
        var moved = boulderBarn
        moved.name = "Boulder Barn Climbing"
        moved.latitude = 51.5210
        moved.radius = 400
        draft.update(moved)
        #expect(draft.locations == [moved, pool])
        #expect(draft.locations.map(\.id) == [boulderBarn.id, pool.id])
    }

    @Test func aPlaceRemovedMeanwhileIsNotBroughtBack() {
        var draft = CardDraft(name: "Gym", code: "1", locations: [boulderBarn])
        draft.locations.removeAll()
        draft.update(boulderBarn)
        #expect(draft.locations.isEmpty)
    }
}

@MainActor
struct ArrivalPlanTests {
    private func card(_ name: String, _ locations: [CardLocation]) -> ArrivalPlan.Card {
        ArrivalPlan.Card(name: name, code: name, barcodeType: .code128, locations: locations)
    }

    private func place(_ name: String, latitude: Double) -> CardLocation {
        CardLocation(name: name, latitude: latitude, longitude: 0)
    }

    @Test func cardsWithoutLocationsAreNotWatched() {
        #expect(ArrivalPlan.arrivals(for: [card("Honeycomb Rewards", [])], near: nil).isEmpty)
    }

    @Test func everyLocationOfEveryCardIsWatched() {
        let cards = [
            card("Local Roast Coffee", [place("A", latitude: 51), place("B", latitude: 52)]),
            card("Green Leaf Pharmacy", [place("C", latitude: 53)])
        ]
        let names = ArrivalPlan.arrivals(for: cards, near: nil).map(\.location.name)
        #expect(names == ["A", "B", "C"])
    }

    @Test func arrivalMessageNamesThePlace() {
        let message = ArrivalPlan.message(at: "Boulder Barn")
        #expect(message.contains("Boulder Barn"))
        #expect(message != "Boulder Barn")
    }

    @Test func nearestLocationsAreKeptWithinTheRegionLimit() {
        let places = (0..<30).map { place("P\($0)", latitude: 50 + Double($0) * 0.01) }
        let here = CLLocation(latitude: 50.295, longitude: 0)  // just north of P29, the furthest place from P0
        let plan = ArrivalPlan.arrivals(for: [card("Local Roast Coffee", places)], near: here)
        #expect(plan.count == ArrivalPlan.regionLimit)
        #expect(plan.first?.location.name == "P29")
        #expect(!plan.contains { $0.location.name == "P0" })
    }

    @Test func theAlertNamesThePlaceAndCarriesTheBarcode() throws {
        let boulderBarn = place("Boulder Barn", latitude: 51.52)
        let arrival = try #require(ArrivalPlan.arrivals(for: [card("Local Roast Coffee", [boulderBarn])], near: nil).first)
        let alert = ArrivalPlan.alert(for: arrival)
        #expect(alert.id == "arrival.\(boulderBarn.id.uuidString)")
        #expect(alert.title == "Local Roast Coffee")
        #expect(alert.body == "You're at Boulder Barn. Your barcode is ready.")
        #expect(alert.code == "Local Roast Coffee")
        #expect(alert.place == boulderBarn)
        #expect(alert.barcodePNG != nil)
    }
}
