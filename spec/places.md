# Places

The places a card is used: adding them on the map or by postcode, the radius round each, adding where you are from the card, removing them, the distances the app shows, and when it uses your location.

A place is a circle: a name, a centre and a radius. A card can have any number, and most have none. Places are stored in the card, so they sync and export with it (DATA-1, DATA-2).

### PLACE-1: Add a place on the map

As a card holder, I want to mark on a map where I use a card, so that the app knows where the card belongs.

- In the edit form, the Locations section lists the card's places, then the Notify When I Arrive switch when there are any, and ends with "Add Location". Its footer says whether arriving at them will remind you (ARR-6).
- "Add Location" opens a sheet titled "Add Location" with a map that fills it, Cancel and Add.
- A pin stays in the middle of the map. Dragging the map moves the place under it. The pin's point marks the centre.
- The map opens on the last location the app has, about 800 metres across. When it has none yet, it follows your location as it arrives.
- The map shows your position as the usual blue dot, and a location button beside the postcode field brings the map back to it.
- Add is disabled until the map has reported its centre. Add saves the point under the pin with the name and radius set in the sheet, and closes it. Cancel closes it and adds nothing.
- A place added without a name is called "Pinned location".
- Places added in the edit form are saved with the card when the form is saved (CARD-5).
- Opening the sheet asks for location permission if it has not been asked before (PLACE-7).

**Since:** 1.3
**Where:** `Cards/UI/Screens/LocationPickerView.swift`, `Cards/UI/Screens/CardEditView.swift:112-136`, `Cards/UI/Components/CardLocationRow.swift`, `CardsUITests/CardsScreenshotTests.swift`

### PLACE-2: Find a place by its postcode

As a card holder, I want to type a postcode and jump there, so that I can add a shop without hunting for it on the map.

- The sheet has a Postcode field that types in capitals, with autocorrection off and a Search key.
- A "Find" button appears once the field has text. While a search runs it is replaced by a spinner.
- Searching asks Apple's geocoder for the text, which can be any address, and takes the first match.
- On a match the map moves there, about 1,200 metres across, and an empty name takes the search text in capitals.
- The radius stays as you set it, before or after the search (PLACE-3).
- When nothing matches, or the search fails, the sheet says "No place found for “<text>”" below the field and the map stays where it is.
- Searching for an empty or blank postcode does nothing.

**Since:** 1.3
**Where:** `Cards/UI/Screens/LocationPickerView.swift:135-214`, `Cards/Core/Services/PostcodeLookup.swift`

### PLACE-3: Set how far round a place counts as there

As a card holder, I want to set the size of a place, so that a big shop or a small café both count when I am inside them.

- The radius starts at 200 m.
- A Radius slider sets it from 50 m to 1,000 m in steps of 25 m, with the value beside it, as "200 m".
- A pink ring round the pin shows the radius at the map's scale as you drag and zoom.
- In the edit form, each place shows its name on one line and its radius below, as "200 m radius".
- A place's name and radius can't be changed once it is added. Remove it and add it again (PLACE-5).

**Since:** 1.3
**Where:** `Cards/UI/Screens/LocationPickerView.swift:35`, `Cards/Core/Models/CardLocation.swift:7`, `Cards/UI/Components/CardLocationRow.swift`

### PLACE-4: Add where I am straight from the card

As a card holder, I want to save the place I am at from the card itself, so that I don't have to open the editor at the till.

- Below the card face, a quiet "Add current location" button opens the same Add Location sheet as the edit form (PLACE-1).
- The sheet opens on the last location the app has, which is normally where you are.
- Add saves the place to the card straight away.
- The button is hidden while you are inside one of the card's places, and shows again once you leave.
- The button also shows when the app doesn't know where you are.

**Since:** 1.3
**Where:** `Cards/UI/Screens/CardDetailView.swift:77-91`, `Cards/UI/Screens/CardDetailView.swift:127-140`, `Cards/Features/CardDetailScreen.swift:41-44`, `CardsUITests/CardsUITests.swift` (`testAddCurrentLocationFromCard`)

### PLACE-5: Remove a place

As a card holder, I want to remove a place I no longer use, so that the card stops showing up there.

- In the edit form, swiping a place to the left removes it.
- The removal is saved when the form is saved. Going back without saving keeps the place.

**Since:** 1.3
**Where:** `Cards/UI/Screens/CardEditView.swift:113-116`

### PLACE-6: See how far away my cards' places are

As a card holder, I want to see how far I am from the places I use each card, so that I can tell which card I need next.

- A card's distance is to the edge of its nearest place's circle. Inside a circle it is 0, and the card counts as here.
- The list shows "Here", in semibold with a filled location arrow, or the distance, such as "350 m", on a white pill at the end of the row.
- The card screen and the widget name the place too: "At Westway", or "350 m · Westway".
- VoiceOver reads "You're at Westway" or "350 m from Westway" (A11Y-1).
- Distances are in the units of the device's region, in the style used for road distances, such as "350 m" or "0.4 mi".
- No distance shows for a card without places, or while the app doesn't know where you are.
- Distances follow your location while the app is open, from fixes about 100 metres accurate, updated after you move 25 metres or more.

**Since:** 1.3
**Where:** `Cards/Core/Models/CardLocation.swift:34-75`, `Cards/UI/Components/ProximityLabel.swift`, `Cards/Core/Services/LocationService.swift`, `CardsTests/CardLocationTests.swift`, `CardsTests/WidgetTests.swift`
**Notes:** Distances only change while the app is in use. On coming back to the app they show the last known location until a new fix arrives.

### PLACE-7: Choose whether the app uses my location

As a card holder, I want the app to ask before it uses my location, and only use it while I am using the app, so that I stay in control of it.

- The app asks for When In Use permission only, and never for Always.
- It asks when the Add Location sheet opens and permission has not been decided (PLACE-1, PLACE-4). Nothing else in the app asks.
- iOS shows the request as "Your location shows how far you are from the places you use your cards, and lets the app remind you of the right card when you arrive."
- Once permission is given, the list starts location updates whenever any card has a place, and uses them to choose which places to watch for arrivals (ARR-3).
- Without permission, places can still be added by postcode or by dragging the map, but no distances show (PLACE-6) and iOS doesn't deliver arrival notifications (ARR-1).

**Since:** 1.3
**Where:** `Cards/Core/Services/LocationService.swift`, `Cards/Features/CardListScreen.swift:35-41`, `Info.plist`
**Notes:** The widget asks Core Location for its own fix (WID-1), and the arrival notifications are watched by iOS (ARR-1). Neither needs the app to be running.
