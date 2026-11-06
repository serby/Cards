@testable import Cards
import CoreLocation
import Testing

/// The rule for whose name a place has in the location picker (PLACE-10):
/// MapKit's, until the person types their own.
struct PlaceNameDraftTests {
    private let joesMarket = CLLocationCoordinate2D(latitude: 51.5090, longitude: -0.1960)
    /// About 11 metres north of Joe's Market: a nudge.
    private let nudged = CLLocationCoordinate2D(latitude: 51.5091, longitude: -0.1960)
    /// About 700 metres north-west: somewhere else.
    private let portobello = CLLocationCoordinate2D(latitude: 51.5150, longitude: -0.2040)
    /// The width of map the picker opens at, in metres.
    private let street: CLLocationDistance = 800

    @Test func aMapTooWideToMarkAPlaceIsNotNamed() {
        let name = PlaceNameDraft()
        // As while the map shows the whole country, waiting for your location.
        #expect(!name.needsName(at: joesMarket, mapWidth: 900_000))
        #expect(!name.needsName(at: joesMarket, mapWidth: nil), "Not before the map says how wide it is")
        #expect(name.needsName(at: joesMarket, mapWidth: PlaceNameDraft.widestNamedMap))
    }

    @Test func aNewPlaceTakesMapKitsName() {
        var name = PlaceNameDraft()
        #expect(name.needsName(at: joesMarket, mapWidth: street))
        name.name("Joe's Market Notting Hill", at: joesMarket)
        #expect(name.text == "Joe's Market Notting Hill")
        #expect(!name.isTyped)
    }

    @Test func movingThePlaceRenamesItWhileTheNameIsMapKits() {
        var name = PlaceNameDraft()
        name.name("Joe's Market Notting Hill", at: joesMarket)
        #expect(name.needsName(at: portobello, mapWidth: street))
        name.name("Portobello Road, Notting Hill", at: portobello)
        #expect(name.text == "Portobello Road, Notting Hill")
    }

    @Test func aNudgeKeepsMapKitsName() {
        var name = PlaceNameDraft()
        name.name("Joe's Market Notting Hill", at: joesMarket)
        #expect(!name.needsName(at: nudged, mapWidth: street))
        #expect(!name.needsName(at: joesMarket, mapWidth: street))
    }

    @Test func aTypedNameIsKeptWhereverThePlaceMoves() {
        var name = PlaceNameDraft()
        name.name("Joe's Market Notting Hill", at: joesMarket)
        name.type("Joe's")
        #expect(name.isTyped)
        #expect(!name.needsName(at: portobello, mapWidth: street))
        // A search result moves the place but leaves the name alone.
        name.name("Local Roast Portobello", at: portobello)
        #expect(name.text == "Joe's")
        #expect(name.savedName == "Joe's")
    }

    @Test func clearingTheFieldHandsTheNameBackToMapKit() {
        var name = PlaceNameDraft()
        name.type("Joe's")
        name.type("")
        #expect(!name.isTyped)
        // Even where the pin already is, so the next rest names it.
        #expect(name.needsName(at: joesMarket, mapWidth: street))
        name.name("Joe's Market Notting Hill", at: joesMarket)
        #expect(name.text == "Joe's Market Notting Hill")
    }

    @Test func spacesAloneAreNotAName() {
        var name = PlaceNameDraft()
        name.type("   ")
        #expect(!name.isTyped)
        #expect(name.savedName == PlaceNameDraft.unnamed)
    }

    @Test func theFieldWritingBackMapKitsNameIsNoChange() {
        var name = PlaceNameDraft()
        name.name("Joe's Market Notting Hill", at: joesMarket)
        name.type("Joe's Market Notting Hill")
        #expect(!name.isTyped)
        #expect(name.needsName(at: portobello, mapWidth: street))
    }

    @Test func mapKitHavingNoNameClearsItsOldOne() {
        var name = PlaceNameDraft()
        name.name("Joe's Market Notting Hill", at: joesMarket)
        name.name(nil, at: portobello)
        #expect(name.text.isEmpty)
        #expect(name.savedName == "Pinned location")
    }

    @Test func aPlaceBeingChangedKeepsItsName() {
        let name = PlaceNameDraft(editing: "Joe's Market Kensington")
        #expect(name.isTyped)
        #expect(!name.needsName(at: portobello, mapWidth: street))
    }

    @Test func aPlaceSavedWithoutANameCanBeNamedByMapKit() {
        var name = PlaceNameDraft(editing: PlaceNameDraft.unnamed)
        #expect(!name.isTyped)
        #expect(name.needsName(at: portobello, mapWidth: street))
        name.name("Portobello Road, Notting Hill", at: portobello)
        #expect(name.savedName == "Portobello Road, Notting Hill")
    }

    @Test func theSavedNameIsTrimmed() {
        var name = PlaceNameDraft()
        name.type("  Boulder Barn  ")
        #expect(name.savedName == "Boulder Barn")
    }
}
