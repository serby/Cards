# Places

The places a card is used: adding them on the map or by searching, what they are called, the radius round each, adding where you are from the card, removing them, the distances the app shows, the list of a card's nearest places, and when it uses your location.

A place is a circle: a name, a centre and a radius. A card can have any number, and most have none. Places are stored in the card, so they sync and export with it (DATA-1, DATA-2).

### PLACE-1: Add a place on the map

As a card holder, I want to mark on a map where I use a card, so that the app knows where the card belongs.

- In the edit form, the Locations section lists the card's places, then the Notify When I Arrive switch when there are any, and ends with "Add Location". Its footer says whether arriving at them will remind you (ARR-6).
- "Add Location" opens a sheet titled "Add Location" with a map that fills it, Cancel and Add.
- A pin stays in the middle of the map. Dragging the map moves the place under it. The pin's point marks the centre.
- The map opens on the last location the app has, about 800 metres across. When it has none yet, it follows your location as it arrives.
- The map shows your position as the usual blue dot, and a location button beside the search field (the postcode field in 1.3) brings the map back to it.
- Add is disabled until the map has reported its centre. Add saves the point under the pin with the name and radius set in the sheet, and closes it. Cancel closes it and adds nothing.
- A place added without a name is called "Pinned location". Since 1.4 the name is filled in from the map (PLACE-10), so this is a place Apple Maps had no name for and you gave none.
- Places added in the edit form are saved with the card when the form is saved (CARD-5).
- Opening the sheet asks for location permission if it has not been asked before (PLACE-7).

**Since:** 1.3
**Where:** `Cards/UI/Screens/LocationPickerView.swift`, `Cards/UI/Screens/CardEditView.swift` (the Locations section), `Cards/UI/Components/CardLocationRow.swift`, `CardsUITests/CardsScreenshotTests.swift`

### PLACE-2: Find a place by searching

As a card holder, I want to search for a shop, an address, a street, a town or a postcode, so that I can add a place without hunting for it on the map.

- In 1.3 the sheet has a Postcode field with a "Find" button. It asks Apple's geocoder for the text, takes the first match, and an empty name takes the search text in capitals.
- Since 1.4 it is a search field instead, "Search for a place", with autocorrection off and a Search key. VoiceOver reads it as "Search for a place", with the hint "Finds shops, addresses, streets, towns and postcodes".
- Since 1.4: once you pause typing for a quarter of a second, Apple Maps suggests businesses and other points of interest, addresses, streets, towns and postcodes, those on or near the map on screen first. They list below the field in place of the name and radius, each as its title over its subtitle, such as "Local Roast Notting Hill" over "Pembridge Road, London W11", and VoiceOver reads both. Four fit before the list scrolls, and scrolling it puts the keyboard away.
- Since 1.4: "Searching…" shows until the first suggestions arrive, and a spinner in the field while new ones are on their way. The last suggestions stay listed until the next arrive.
- Since 1.4: choosing a suggestion, or pressing Search without choosing one, which takes Apple Maps' best match, puts its title in the field, closes the list and moves the map and the place's circle there, about 1,200 metres across. The place takes the name of what was found (PLACE-10), and VoiceOver says "Showing <name> on the map".
- Since 1.4: a clear button in the field empties it and closes the list. Going back to the field with text in it shows the list again.
- The radius stays as you set it, before or after the search (PLACE-3).
- When nothing matches, the sheet says "No place found for “<text>”" below the field, and the map stays where it is. Since 1.4 that is said as you type, and also after pressing Search, when VoiceOver reads it out.
- Since 1.4: when the device is offline the sheet says "You are offline. Connect to the internet to search, or drag the map to the place.", and when Apple Maps cannot answer, "Search is not working right now. Try again, or drag the map to the place."
- Searching for empty or blank text does nothing.

**Since:** 1.3
**Where:** `Cards/UI/Screens/LocationPickerView.swift`, `Cards/UI/Components/PlaceSearchResults.swift`, `Cards/UI/ViewState/PlaceSearchStatus.swift`, `Cards/Core/Services/PlaceSearch.swift`, `Cards/Core/Services/PlaceSearch+MapKit.swift`, `CardsTests/PlaceSearchTests.swift`, `CardsUITests/CardPlacesAndSettingsUITests.swift` (`testFindAPlaceBySearch`)
**Notes:** Each suggestion is looked up again when chosen, as Apple Maps' suggestions cannot be kept, so a suggestion Apple Maps has since dropped is found by its title and subtitle instead. Choosing a suggestion for an area can find a point of interest in it, such as "Wembley Park" finding Wembley Park Station.

### PLACE-3: Set how far round a place counts as there

As a card holder, I want to set the size of a place, so that a big shop or a small café both count when I am inside them.

- The radius starts at 50 m; until 1.5 it started at 200 m.
- A Radius slider sets it from 25 m to 1,000 m in steps of 25 m, with the value beside it, as "50 m". Until 1.5 it started at 50 m.
- Since 1.4: the radius is in the units chosen in Settings > Distances (SET-4). With Miles, or Automatic where the measurement system is UK or US, it is in yards: the slider runs from 25 yd to 1,100 yd in steps of 25 yd (50 yd until 1.5), and the 50 m a place starts with shows as "55 yd". A radius is shown to the nearest 5 m or 5 yd, and is kept in metres whichever unit set it, so a place set in yards shows its metres rounded, as "230 m" for 250 yd.
- A pink ring round the pin shows the radius at the map's scale as you drag and zoom.
- In the edit form, each place shows its name on one line and its radius below, as "200 m radius", or in preparation for 1.4 "220 yd radius" in yards.
- In 1.3 a place's name and radius can't be changed once it is added; you remove it and add it again (PLACE-5). Since 1.4, tapping the place changes it (PLACE-8).

**Since:** 1.3
**Where:** `Cards/Core/Models/CardLocation.swift` (`defaultRadius`, `radiusRange`), `Cards/Core/Models/DistanceFormat.swift` (`radius(_:width:)`, `RadiusScale`), `Cards/UI/Screens/LocationPickerView.swift`, `Cards/UI/Components/RadiusSlider.swift`, `Cards/UI/Components/CardLocationRow.swift`, `CardsTests/DistanceFormatTests.swift`
**Notes:** A shared card's radii are kept between 25 m and 1,000 m when it is added (SHARE-3), so a place at either end of the yards slider, 25 yd (23 m) or 1,100 yd (1,006 m), arrives as 25 m or 1,000 m. Paul set the 25 m smallest radius and the 50 m start on 14 November 2026; places made before keep their radius. A place this small is smaller than a phone's position is often accurate to indoors, so being "Here" (PLACE-6) and an arrival reminder (ARR-1), which iOS judges from the network as much as from GPS, can be late or missed for one.

### PLACE-4: Add where I am straight from the card

As a card holder, I want to save the place I am at from the card itself, so that I don't have to open the editor at the till.

- Below the card face, a quiet "Add current location" button opens the same Add Location sheet as the edit form (PLACE-1).
- The sheet opens on the last location the app has, which is normally where you are. Since 1.4 its name is filled in with what Apple Maps calls that spot (PLACE-10).
- Add saves the place to the card straight away.
- The button is hidden while you are inside one of the card's places, and shows again once you leave.
- The button also shows when the app doesn't know where you are.

**Since:** 1.3
**Where:** `Cards/UI/Screens/CardDetailView.swift`, `Cards/UI/Screens/CardDetailView.swift`, `Cards/Features/CardDetailScreen.swift`, `CardsUITests/CardPlacesAndSettingsUITests.swift` (`testAddCurrentLocationFromCard`)

### PLACE-5: Remove a place

As a card holder, I want to remove a place I no longer use, so that the card stops showing up there.

- In the edit form, swiping a place to the left removes it.
- The removal is saved when the form is saved. Going back without saving keeps the place.

**Since:** 1.3
**Where:** `Cards/UI/Screens/CardEditView.swift` (the Locations section's `onDelete`)

### PLACE-6: See how far away my cards' places are

As a card holder, I want to see how far I am from the places I use each card, so that I can tell which card I need next.

- A card's distance is to the edge of its nearest place's circle. Inside a circle it is 0, and the card counts as here.
- The list shows "Here", in semibold with a filled location arrow, or the distance, such as "350 m", on a white pill at the end of the row.
- The card screen and the widget name the place too: "At Boulder Barn", or "350 m · Boulder Barn".
- Since 1.4: inside more than one of a card's places, the one whose middle you are nearer is named, where before it was the first in the card's order. A card with more than one place also lists its nearest five on the card screen (PLACE-9).
- Since 1.4: on the card screen, tapping the place in the top panel opens it in the maps app chosen in Settings > Maps, Apple Maps unless Google Maps is chosen (SET-5), as a place in the list does (PLACE-9), whether the card has one place or several. VoiceOver reads it as a button with the hint "Opens this place in Maps", or "Opens this place in Google Maps". The tile on the Cards tab, the card for where you are and a shared card's image don't open it.
- VoiceOver reads "You're at Boulder Barn" or "350 m from Boulder Barn" (A11Y-1). Since 1.4 it says the units in full: "350 metres from Boulder Barn".
- Distances are in the units of the device's region, in the style used for road distances, such as "350 m" or "0.4 mi". Since 1.4 they are in the units chosen in Settings > Distances, which follows the device's measurement system unless you choose Kilometres or Miles (SET-4).
- No distance shows for a card without places, or while the app doesn't know where you are.
- Distances follow your location while the app is open, from fixes about 100 metres accurate, updated after you move 25 metres or more.

**Since:** 1.3
**Where:** `Cards/Core/Models/CardLocation.swift`, `Cards/Core/Models/DistanceFormat.swift`, `Cards/UI/Components/ProximityLabel.swift`, `Cards/UI/Components/CardFaceView.swift` (`linksNearestPlace`), `Cards/UI/ViewState/CardViewState.swift` (`CardDetail.nearestPlace`), `CardsTests/DistanceFormatTests.swift`, `Cards/Core/Services/LocationService.swift`, `CardsTests/CardLocationTests.swift`, `CardsTests/CardPlacesTests.swift`, `CardsTests/WidgetTests.swift`
**Notes:** Distances only change while the app is in use. On coming back to the app they show the last known location until a new fix arrives.

### PLACE-7: Choose whether the app uses my location

As a card holder, I want the app to ask before it uses my location, and only use it while I am using the app, so that I stay in control of it.

- The app asks for When In Use permission only, and never for Always.
- It asks when the Add Location sheet opens and permission has not been decided (PLACE-1, PLACE-4). Nothing else in the app asks.
- iOS shows the request as "Your location shows how far you are from the places you use your cards, and lets the app remind you of the right card when you arrive."
- Once permission is given, the list starts location updates whenever any card has a place, and uses them to choose which places to watch for arrivals (ARR-3).
- Without permission, places can still be added by searching (by postcode in 1.3) or by dragging the map, but no distances show (PLACE-6) and iOS doesn't deliver arrival notifications (ARR-1).

**Since:** 1.3
**Where:** `Cards/Core/Services/LocationService.swift`, `Cards/Features/CardListScreen.swift`, `Info.plist`
**Notes:** The widget asks Core Location for its own fix (WID-1), and the arrival notifications are watched by iOS (ARR-1). Neither needs the app to be running.

### PLACE-8: Change a place

As a card holder, I want to change a place I added, so that I can fix its name, its position or its radius without adding it again.

- In the edit form, tapping a place opens the location picker (PLACE-1) with that place's name, position and radius filled in. The sheet's title is "Edit Location" and its confirm button is "Save".
- The map opens centred on the place, at least 800 metres across and wide enough to show the whole ring, so Save works straight away.
- Moving the map, searching (PLACE-2), renaming the place or changing the radius, then tapping Save, updates the place in the form, in the same position in the list. Cancel leaves it as it was. A name left empty becomes "Pinned location", as when adding (PLACE-1). The place keeps its name when you move it, unless it is called "Pinned location" (PLACE-10).
- The place keeps its identity, so its arrival reminder is replaced rather than joined by a second one. The change is kept when the card is saved (CARD-5), and arrival reminders use the new position and radius from then on (ARR-3). Going back from the form without saving keeps the place as it was.
- VoiceOver reads a place's row as a button, with the hint "Opens the map to change this place".
- Swiping a place to remove it still works as before (PLACE-5).

**Since:** 1.4
**Where:** `Cards/UI/Screens/CardEditView.swift`, `Cards/UI/Screens/LocationPickerView.swift` (`init(editing:search:onAppear:onSave:)`), `Cards/UI/ViewState/CardViewState.swift` (`CardDraft.update(_:)`), `CardsTests/CardLocationTests.swift` (`changingAPlaceInTheFormKeepsItsSpotAndId`, `aPlaceRemovedMeanwhileIsNotBroughtBack`), `CardsUITests/CardPlacesAndSettingsUITests.swift` (`testEditAPlace`)

### PLACE-9: See a card's nearest places

As a card holder, I want to see which of a card's places are nearest and how far away each is, so that I can tell which shop to go to.

- When a card has more than one place, the card screen lists them on a white panel at the foot of the card face, below the number and the date, under the heading "Nearest places". The panel is the width of the others, its corners nest inside the card's (COL-3), and it stays white in dark mode.
- It lists the nearest five, nearest first, each with its name and its distance: "Here", in semibold in its capsule, inside the place's circle, or the distance to the edge of the circle, such as "350 m" (PLACE-6). Names are in dark ink and distances in the lighter ink for supporting text.
- Between places you are inside, the one whose middle you are nearer comes first, and places the same distance away keep the card's order. The top panel names the first of them (PLACE-6).
- A card with more than five places lists five and ends with a quiet "2 more places", or "1 more place", in footnote size. It is not a button, and there is no way to see the rest on the card screen; the edit form lists them all (PLACE-1).
- While the app doesn't know where you are, with no permission or no fix yet, the heading is "Places" and it lists the first five in the card's order, without distances.
- A card with one place shows no list, since the top panel already names it (CARD-4), and a card with no places shows none either.
- The list follows your location as the distances do (PLACE-6), so the order changes as you move.
- Tapping a place opens it in the maps app chosen in Settings > Maps (SET-5), where you can get directions: in Apple Maps, the default, as a pin with the place's name, and in Google Maps as a pin at its position.
- A long name wraps onto as many lines as it needs, and the distance stays on one line beside it. At the accessibility text sizes the distance moves below the name (A11Y-3).
- Each place is at least 44 points high, with a hairline between places.
- The card screen scrolls when the list makes it taller than the screen.
- VoiceOver reads the heading as a heading, and each place as a button that reads as the distance does, "You're at Joe's Market Notting Hill" or "350 metres from Joe's Market Kensington" (SET-4), or just the name while the app doesn't know where you are, with the hint "Opens this place in Maps", or "Opens this place in Google Maps" (A11Y-1).

**Since:** 1.4
**Where:** `Cards/Core/Models/CardPlaces.swift`, `Cards/Core/Models/CardLocation.swift` (`nearest(_:to:)`, `mapsURL(in:)`), `Cards/UI/Screens/CardDetailView.swift` (`PlacesPanel`), `Cards/UI/Components/CardFaceView.swift` (`footer`), `Cards/Features/CardDetail+CardItem.swift`, `CardsTests/CardPlacesTests.swift`
**Notes:** The nearest place shows twice, in the top panel and first in the list. Joe's Market has two places in the screenshot cards, so its card screen shows the list.

### PLACE-10: Name a place from the map

As a card holder, I want a place to be named for what is there, so that I don't have to type a name for every shop.

- The name field is filled in with what Apple Maps calls the place, however it was set: a search result (PLACE-2), the point under the pin once you stop dragging the map, or where you are when the sheet opens or the location button is tapped (PLACE-1, PLACE-4).
- A business or other point of interest goes by its own name, such as "Local Roast Notting Hill" or a park's or station's. An address or street goes by the street, without its house number, and the area, such as "Portobello Road, Kensington and Chelsea". A postcode or town with no street goes by what Apple Maps calls it, such as "W11 3JE".
- A dropped pin, and where you are, are named by Apple Maps' reverse geocoder: on iOS 26 and later through MapKit, and on iOS 18 to 25 through Core Location. Both give the same names for the same spots.
- The pin is named about a second after the map comes to rest, and only once the map is 5 km across or less. Wider than that, as while the map waits for your location, the pin marks a region rather than a place.
- Nudging the pin less than 25 metres from where Apple Maps last named it keeps that name, so a search result's name stays while you line the pin up with its door.
- You can edit the name at any time. Once you type a name of your own it stays, whatever you do next: moving the map, searching, going to your location or changing the radius never replace it. A search still moves the map. Changing the radius never changes the name in any case.
- VoiceOver reads the name field as "Place name", followed by the name in it, so a filled-in field still says what it is for.
- Clearing the name field hands the name back to Apple Maps, which names the place the next time it moves, never while you are typing in the field.
- When Apple Maps has no name for a spot the pin moves to, or cannot be reached, a name it gave an earlier spot is cleared rather than left on the wrong place. A place saved with no name is "Pinned location" (PLACE-1).
- When changing a place (PLACE-8), its name counts as your own and stays when you move it, unless it is "Pinned location", which Apple Maps may replace.

**Since:** 1.4
**Where:** `Cards/UI/ViewState/PlaceNameDraft.swift`, `Cards/Core/Models/PlaceFields.swift`, `Cards/Core/Services/PlaceSearch+MapKit.swift`, `Cards/UI/Screens/LocationPickerView.swift`, `CardsTests/PlaceNameDraftTests.swift`, `CardsTests/PlaceSearchTests.swift`, `CardsUITests/CardPlacesAndSettingsUITests.swift` (`testAddCurrentLocationFromCard`, `testFindAPlaceBySearch`)
**Notes:** In London, Apple Maps' area is the borough, so names can be long, such as "Vicarage Gate, Kensington and Chelsea". Debug builds launched for UI tests search made-up places instead of Apple Maps (`DevelopmentHooks.placeSearch`).
