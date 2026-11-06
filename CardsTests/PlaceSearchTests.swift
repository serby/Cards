@testable import Cards
import CoreLocation
import Foundation
import MapKit
import Testing

/// How places are named from what MapKit says (PLACE-10), how search errors
/// read, and the stand-in search the stories and UI tests use. The MapKit
/// fields below are what MapKit returned for these places in London.
struct PlaceSearchTests {
    // MARK: - Naming

    @Test func aPointOfInterestGoesByItsOwnName() {
        let fields = PlaceFields(
            name: "Joe's Market Notting Hill",
            isPointOfInterest: true,
            street: "Notting Hill Gate",
            area: "Kensington and Chelsea"
        )
        #expect(fields.placeName == "Joe's Market Notting Hill")
    }

    @Test func anAddressGoesByItsStreetAndArea() {
        let fields = PlaceFields(name: "191 Portobello Road", street: "Portobello Road", area: "Kensington and Chelsea")
        #expect(fields.placeName == "Portobello Road, Kensington and Chelsea")
    }

    @Test func aStreetThatNamesItsAreaIsNotRepeated() {
        let fields = PlaceFields(name: "Wembley Park Drive", street: "Wembley Park Drive", area: "Wembley")
        #expect(fields.placeName == "Wembley Park Drive")
    }

    @Test(arguments: [
        (PlaceFields(name: "W11 3JE", area: "Kensington and Chelsea"), "W11 3JE"),
        (PlaceFields(name: "Kensington", area: "Kensington and Chelsea"), "Kensington"),
        (PlaceFields(name: "  ", area: "Notting Hill"), "Notting Hill")
    ])
    func withNoStreetMapKitsNameOrTheAreaIsUsed(fields: PlaceFields, expected: String) {
        #expect(fields.placeName == expected)
    }

    @Test func withNothingToGoOnThereIsNoName() {
        #expect(PlaceFields().placeName == nil)
        #expect(PlaceFields(name: " ", isPointOfInterest: true, street: "", area: nil).placeName == nil)
    }

    /// A placemark's fields, as iOS 18 to 25 give them.
    @Test(arguments: [
        // A dropped pin on a street.
        (PlaceFields(
            name: "191 Portobello Road",
            thoroughfare: "Portobello Road",
            subLocality: "Kensington and Chelsea",
            locality: "London",
            areasOfInterest: [],
            isPointOfInterest: false
        ), "Portobello Road, Kensington and Chelsea"),
        // A street that is also an area of interest goes by that name.
        (PlaceFields(
            name: "Notting Hill Gate",
            thoroughfare: "Notting Hill Gate",
            subLocality: "Kensington and Chelsea",
            locality: "London",
            areasOfInterest: ["Notting Hill Gate"],
            isPointOfInterest: false
        ), "Notting Hill Gate"),
        // A park, whose placemark street is a lodge's.
        (PlaceFields(
            name: "Hyde Park",
            thoroughfare: "Rangers Lodge",
            subLocality: "City of Westminster",
            locality: "London",
            areasOfInterest: ["Hyde Park"],
            isPointOfInterest: false
        ), "Hyde Park"),
        // A postcode has no street.
        (PlaceFields(
            name: "W11 3JE",
            thoroughfare: nil,
            subLocality: "Kensington and Chelsea",
            locality: "London",
            areasOfInterest: [],
            isPointOfInterest: false
        ), "W11 3JE"),
        // A business found by search.
        (PlaceFields(
            name: "Local Roast Portobello",
            thoroughfare: "Portobello Road",
            subLocality: "Kensington and Chelsea",
            locality: "London",
            areasOfInterest: [],
            isPointOfInterest: true
        ), "Local Roast Portobello"),
        // No district, so the town.
        (PlaceFields(
            name: "12 Portobello Road",
            thoroughfare: "Portobello Road",
            subLocality: nil,
            locality: "London",
            areasOfInterest: [],
            isPointOfInterest: false
        ), "Portobello Road, London")
    ])
    func placemarkFieldsAreNamed(fields: PlaceFields, expected: String) {
        #expect(fields.placeName == expected)
    }

    /// A map item's fields, as iOS 26 and later give them, for the same places,
    /// which get the same names.
    @Test(arguments: [
        (PlaceFields(
            name: "191 Portobello Road",
            shortAddress: "191 Portobello Road, London",
            cityName: "Kensington and Chelsea, London",
            isPointOfInterest: false
        ), "Portobello Road, Kensington and Chelsea"),
        (PlaceFields(
            name: "Notting Hill Gate",
            shortAddress: "52\u{2013}74 Notting Hill Gate, London",
            cityName: "Kensington and Chelsea, London",
            isPointOfInterest: false
        ), "Notting Hill Gate"),
        (PlaceFields(
            name: "Hyde Park",
            shortAddress: "Rangers Lodge, Serpentine Road, London",
            cityName: "City of Westminster, London",
            isPointOfInterest: false
        ), "Hyde Park"),
        (PlaceFields(
            name: "W11 3JE",
            shortAddress: "Kensington and Chelsea, London",
            cityName: "Kensington and Chelsea, London",
            isPointOfInterest: false
        ), "W11 3JE"),
        (PlaceFields(
            name: "Local Roast Portobello",
            shortAddress: "180 Portobello Road, London",
            cityName: "London",
            isPointOfInterest: true
        ), "Local Roast Portobello"),
        (PlaceFields(
            name: "12 Portobello Road",
            shortAddress: "12 Portobello Road, London",
            cityName: "London",
            isPointOfInterest: false
        ), "Portobello Road, London")
    ])
    func mapItemFieldsAreNamed(fields: PlaceFields, expected: String) {
        #expect(fields.placeName == expected)
    }

    @Test func aHouseNumberRangeIsLeftOffTheStreet() {
        let fields = PlaceFields(name: nil, shortAddress: "52\u{2013}74 Notting Hill Gate, London", cityName: "London", isPointOfInterest: false)
        #expect(fields.street == "Notting Hill Gate")
    }

    // MARK: - Errors

    @Test(arguments: [
        NSError(domain: MKError.errorDomain, code: Int(MKError.Code.placemarkNotFound.rawValue)),
        NSError(domain: kCLErrorDomain, code: CLError.Code.geocodeFoundNoResult.rawValue)
    ])
    func findingNothingIsNotAnError(error: NSError) {
        #expect(PlaceSearchError(error) == nil)
    }

    @Test(arguments: [
        NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet),
        NSError(domain: kCLErrorDomain, code: CLError.Code.network.rawValue),
        NSError(
            domain: MKError.errorDomain,
            code: Int(MKError.Code.serverFailure.rawValue),
            userInfo: [NSUnderlyingErrorKey: NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)]
        ),
        // Nothing found, because there was no network to ask.
        NSError(
            domain: MKError.errorDomain,
            code: Int(MKError.Code.placemarkNotFound.rawValue),
            userInfo: [NSUnderlyingErrorKey: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)]
        )
    ])
    func aNetworkFailureIsOffline(error: NSError) {
        #expect(PlaceSearchError(error) == .offline)
    }

    @Test(arguments: [
        NSError(domain: MKError.errorDomain, code: Int(MKError.Code.loadingThrottled.rawValue)),
        NSError(domain: MKError.errorDomain, code: Int(MKError.Code.serverFailure.rawValue)),
        NSError(domain: "Elsewhere", code: 1)
    ])
    func anyOtherFailureIsSearchNotWorking(error: NSError) {
        #expect(PlaceSearchError(error) == .unavailable)
    }

    // MARK: - What the search field shows

    @Test func anEmptyAnswerReadsAsNoPlaceFound() {
        #expect(PlaceSearchStatus.answer([], to: "Corner Grocer") == .notFound("Corner Grocer"))
        #expect(PlaceSearchStatus.notFound(" Corner Grocer ").message == "No place found for \u{201C}Corner Grocer\u{201D}")
    }

    @Test func suggestionsAreListedWithNoMessage() {
        let suggestions = PlaceSuggestion.samples(for: "Joe")
        #expect(PlaceSearchStatus.answer(suggestions, to: "Joe") == .found(suggestions))
        #expect(PlaceSearchStatus.found(suggestions).message == nil)
    }

    @Test func failuresSayWhatToDo() {
        #expect(PlaceSearchStatus.failure(PlaceSearchError.offline) == .failed(.offline))
        #expect(PlaceSearchStatus.failure(CancellationError()) == .failed(.unavailable))
        #expect(PlaceSearchStatus.failed(.offline).message?.hasPrefix("You are offline.") == true)
        #expect(PlaceSearchStatus.failed(.unavailable).message?.hasPrefix("Search is not working right now.") == true)
    }

    // MARK: - The stand-in

    @Test @MainActor func theSampleSearchSuggestsOnlyMadeUpBusinesses() async throws {
        let titles = try await PlaceSearch.sample.suggest("Joe", nil).map(\.title)
        #expect(titles == ["Joe's Market Notting Hill", "Joe's Market Kensington", "Joe's Market Holland Park"])
        // docs/LANGUAGE.md: examples use the made-up cast, never a real business.
        let cast = ["Joe's Market", "Local Roast", "Green Leaf", "Boulder Barn", "Nordic Nest"]
        for place in SamplePlace.all where place.fields.isPointOfInterest {
            #expect(cast.contains { place.title.hasPrefix($0) }, "\(place.title) is not in the language guide's cast")
        }
    }

    @Test @MainActor func theSampleSearchFindsAndNamesPlaces() async throws {
        let suggestions = try await PlaceSearch.sample.suggest("Portobello Road", nil)
        // Local Roast Portobello is on Portobello Road, so it is suggested too.
        #expect(suggestions.map(\.title) == ["Local Roast Portobello", "Portobello Road"])
        let suggestion = try #require(suggestions.last)
        let street = try #require(try await PlaceSearch.sample.place(suggestion, nil))
        #expect(street.name == "Portobello Road, Notting Hill")

        #expect(try await PlaceSearch.sample.bestMatch("local roast", nil)?.name == "Local Roast Portobello")
        #expect(try await PlaceSearch.sample.bestMatch("Corner Grocer", nil) == nil)
    }

    @Test @MainActor func theSampleSearchNamesADroppedPin() async throws {
        // The screenshot seed's location, beside Joe's Market Notting Hill.
        let besideTheShop = CLLocationCoordinate2D(latitude: 51.5091, longitude: -0.1963)
        #expect(try await PlaceSearch.sample.name(besideTheShop) == "Joe's Market Notting Hill")
        let openStreet = CLLocationCoordinate2D(latitude: 51.5300, longitude: -0.1500)
        #expect(try await PlaceSearch.sample.name(openStreet) == "Pembridge Road, Notting Hill")
    }
}
