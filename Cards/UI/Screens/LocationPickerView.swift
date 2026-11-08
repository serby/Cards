import MapKit
import SwiftUI

/// Picks a place for a card: search for it, or drag the map under the pin,
/// then set how far around it counts as "there". MapKit names the place until
/// you type a name of your own (PLACE-10). Adds a new place, or changes one the
/// card already has (PLACE-8).
public struct LocationPickerView: View {
    /// The place being changed, or nil when adding one.
    let editing: CardLocation?
    let search: PlaceSearch
    private let onAppear: () -> Void
    let onConfirm: (CardLocation) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.mapShowsPointsOfInterest) private var showsPointsOfInterest
    @Environment(\.accessibilityAnnouncer) var announcer
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.distanceFormat) private var distanceFormat
    @State var position: MapCameraPosition
    /// The point under the pin. Kept as plain values so an unchanged camera
    /// never invalidates the view (MapKit reports camera changes generously).
    @State var center: MapPoint?
    @State var metresPerPoint: Double?
    @State var mapWidth: CGFloat = 0
    @State var radius = CardLocation.defaultRadius
    @State var name: PlaceNameDraft
    @State var query: String
    /// Whether the panel lists suggestions in place of the name and radius:
    /// from typing in the search field until a place is chosen or it is cleared.
    @State var showsSuggestions: Bool
    @State var results = PlaceSearchStatus.searching
    @State var isSuggesting = false
    /// Finding the place a suggestion, or return, stands for.
    @State var isFinding = false
    /// Why the last place looked for was not found, shown below the search field.
    @State var findProblem: PlaceSearchStatus?
    @FocusState var focusedField: Field?
    /// How tall the controls under the map are, so their scroll view takes no more.
    @State private var controlsHeight: CGFloat = 0
    @Namespace private var mapScope

    enum Field {
        case search, name
    }

    struct MapPoint: Equatable {
        let latitude: CLLocationDegrees
        let longitude: CLLocationDegrees

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    /// What the suggestion list is waiting for: new text, or the list showing again.
    private struct SuggestionRequest: Equatable {
        let text: String
        let isShowing: Bool
    }

    /// What naming the pin waits for: the map coming to rest somewhere, or
    /// zooming in close enough for the pin to mark a place. Not the name being
    /// cleared, so MapKit never fills the field while you type in it.
    private struct PinRest: Equatable {
        let point: MapPoint?
        let isStreetLevel: Bool
    }

    /// `query` starts the search field with text, and its suggestions showing.
    public init(
        initialPosition: MapCameraPosition = .userLocation(fallback: .automatic),
        search: PlaceSearch = .unavailable,
        query: String = "",
        onAppear: @escaping () -> Void = {},
        onAdd: @escaping (CardLocation) -> Void
    ) {
        self.init(position: initialPosition, editing: nil, search: search, query: query, onAppear: onAppear, onConfirm: onAdd)
    }

    /// Opens on `location` with its name and radius filled in, titled "Edit
    /// Location". Save hands back the changed place, with the same `id`.
    public init(
        editing location: CardLocation,
        search: PlaceSearch = .unavailable,
        onAppear: @escaping () -> Void = {},
        onSave: @escaping (CardLocation) -> Void
    ) {
        // Wide enough to show the whole ring round the pin, and never closer than adding opens.
        let span = max(800, location.radius * 4)
        self.init(
            position: .region(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: span, longitudinalMeters: span)),
            editing: location,
            search: search,
            query: "",
            onAppear: onAppear,
            onConfirm: onSave
        )
    }

    /// Opens at `centre`, normally the user's last known location, or follows the
    /// user's location when there is none yet.
    public init(
        centre: CLLocationCoordinate2D?,
        search: PlaceSearch = .unavailable,
        onAppear: @escaping () -> Void = {},
        onAdd: @escaping (CardLocation) -> Void
    ) {
        self.init(
            initialPosition: centre.map { centre in
                .region(MKCoordinateRegion(center: centre, latitudinalMeters: 800, longitudinalMeters: 800))
            } ?? .userLocation(fallback: .automatic),
            search: search,
            onAppear: onAppear,
            onAdd: onAdd
        )
    }

    private init(
        position: MapCameraPosition,
        editing: CardLocation?,
        search: PlaceSearch,
        query: String,
        onAppear: @escaping () -> Void,
        onConfirm: @escaping (CardLocation) -> Void
    ) {
        _position = State(initialValue: position)
        _query = State(initialValue: query)
        _showsSuggestions = State(initialValue: !query.trimmed.isEmpty)
        if let editing {
            _name = State(initialValue: PlaceNameDraft(editing: editing.name))
            _radius = State(initialValue: editing.radius)
            // The map reports its centre once it appears; until then it is the place's.
            _center = State(initialValue: MapPoint(latitude: editing.latitude, longitude: editing.longitude))
        } else {
            _name = State(initialValue: PlaceNameDraft())
        }
        self.editing = editing
        self.search = search
        self.onAppear = onAppear
        self.onConfirm = onConfirm
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                map
                MapPinRing(diameter: metresPerPoint.map { 2 * radius / $0 })
                    .voiceOverMapPin(name: name.savedName, radius: radius, in: distanceFormat, onMove: nudge)
            }
            .safeAreaInset(edge: .bottom) {
                // Scrolls when it does not fit, as at large text sizes with the
                // keyboard up, so the field being typed in stays on screen. One
                // scroll view, as tall as the controls or as the space allows:
                // a ViewThatFits swapped in a second copy of the fields when the
                // keyboard came up, and the field just tapped lost its focus.
                ScrollView {
                    controls
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { controlsHeight = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: controlsHeight)
            }
            .mapScope(mapScope)
                .navigationTitle(
                    editing == nil
                        ? Text("Add Location", comment: "Title of the map sheet for adding a place where a card is used.")
                        : Text("Edit Location", comment: "Title of the map sheet for changing one of a card's places.")
                )
                .navigationBarTitleDisplayMode(.inline)
                // Opaque, so the bar's buttons are read against the bar and not
                // against whatever map shows through a translucent one.
                .toolbarBackground(Color.primaryBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("Cancel", comment: "Closes the Add Location sheet without adding a place.") }
                            .keyboardShortcut(.cancelAction)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: confirm) {
                            editing == nil
                                ? Text("Add", comment: "Toolbar button that adds the place under the map pin to the card. A verb.")
                                : Text("Save", comment: "Toolbar button on the Edit Location map that saves the changed place. A verb.")
                        }
                        .disabled(center == nil)
                        // Command-Return, as Return searches from the search field.
                        .keyboardShortcut(.return, modifiers: .command)
                        .accessibilityIdentifier(editing == nil ? "addLocationButton" : "saveLocationButton")
                    }
                }
        }
        .onAppear(perform: onAppear)
        .task(id: SuggestionRequest(text: query, isShowing: showsSuggestions)) { await suggest() }
        .task(id: PinRest(point: center, isStreetLevel: (mapWidthInMetres ?? .infinity) <= PlaceNameDraft.widestNamedMap)) {
            await nameThePlaceUnderThePin()
        }
    }

    /// The map never changes its own content while you drag: the radius ring
    /// is drawn over it in screen space. Updating map content from camera
    /// changes makes MapKit re-apply the camera, which loops.
    private var map: some View {
        Map(position: $position, scope: mapScope) {
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: showsPointsOfInterest ? .all : .excludingAll))
        .mapControls {}
        .onMapCameraChange(frequency: .continuous) { context in
            let centre = context.region.center
            let point = MapPoint(latitude: centre.latitude, longitude: centre.longitude)
            if point != center { center = point }
            guard mapWidth > 0 else { return }
            let metres = context.rect.size.width * MKMetersPerMapPointAtLatitude(centre.latitude) / mapWidth
            if metres != metresPerPoint { metresPerPoint = metres }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { mapWidth = $0 }
        // The map draws under the bars and the panel but keeps its camera centre,
        // logo and legal link inside the safe area, like the pin overlay does.
        .accessibilityIdentifier("locationPickerMap")
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                searchField
                    .pickerField("magnifyingglass")
                MapUserLocationButton(scope: mapScope)
            }

            if showsSuggestions {
                PlaceSearchResults(status: results, onChoose: choose)
            } else {
                if let findProblem {
                    PlaceSearchResults(status: findProblem)
                }

                // Wraps rather than cutting a long name off at large text sizes.
                TextField(text: nameText, prompt: Text(verbatim: ""), axis: .vertical) { placeNameLabel }
                    .submitLabel(.done)
                    .focused($focusedField, equals: .name)
                    // The label and identifier go on the field: on the row they
                    // replaced those of everything in it, the prompt and icon too.
                    .accessibilityLabel(placeNameLabel)
                    .accessibilityIdentifier("locationNameField")
                    .wrappingPrompt(namePrompt, isShown: name.text.isEmpty) { focusedField = .name }
                    .pickerField("tag")

                RadiusSlider(radius: $radius)
            }
        }
        .padding(18)
        // Opaque, like the bar: a translucent panel let map tiles show through
        // the text, and the audit measured the radius heading below AA on one.
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.primaryBackground)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            // Wraps rather than cutting the text off at large text sizes; Return
            // finds the best match.
            TextField(
                text: Binding(get: { query }, set: edit).singleLine(onReturn: findBestMatch),
                prompt: Text(verbatim: ""),
                axis: .vertical
            ) { searchPrompt }
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($focusedField, equals: .search)
            .accessibilityLabel(searchPrompt)
            .accessibilityHint(
                Text("Finds shops, addresses, streets, towns and postcodes", comment: "VoiceOver hint of the location map's search field.")
            )
            .accessibilityIdentifier("placeSearchField")
            // The prompts are the fields' only visible labels, so they wrap
            // rather than being cut off, in readable secondary text rather
            // than the system placeholder grey (1.7:1 on the field).
            .wrappingPrompt(searchPrompt, isShown: query.isEmpty) { focusedField = .search }
            if isFinding || (showsSuggestions && isSuggesting) {
                ProgressView()
                    // The clear button's size, so swapping the two never moves the field.
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(
                        Text("Searching", comment: "VoiceOver label for the spinner beside the map's search field while a search runs.")
                    )
            } else if !query.isEmpty {
                Button(action: clearSearch) {
                    Label(clearSearchTitle, systemImage: "xmark.circle.fill")
                        // The whole 44 pt square is the button, not just the icon.
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("clearPlaceSearchButton")
            }
        }
        .onChange(of: focusedField) { _, field in
            // Back in the search field, show what it suggests again.
            if field == .search, !query.trimmed.isEmpty { showsSuggestions = true }
        }
    }

    /// How wide the map is in metres, once it has said.
    var mapWidthInMetres: Double? {
        metresPerPoint.map { $0 * mapWidth }
    }

    /// The map on screen, which searches lean towards. Before the map has
    /// reported its size, the 800 metres it opens at round its centre.
    var searchRegion: MKCoordinateRegion? {
        guard let center else { return nil }
        let width = mapWidthInMetres ?? 800
        return MKCoordinateRegion(center: center.coordinate, latitudinalMeters: width, longitudinalMeters: width)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

#if DEBUG
#Preview("Adding") {
    LocationPickerView(initialPosition: .region(CardLocation.previewRegion), search: .sample, onAdd: { _ in })
        .environment(\.accessibilityAnnouncer, .silent)
}

#Preview("Suggestions") {
    LocationPickerView(initialPosition: .region(CardLocation.previewRegion), search: .sample, query: "Joe", onAdd: { _ in })
        .environment(\.accessibilityAnnouncer, .silent)
}

#Preview("Offline") {
    LocationPickerView(initialPosition: .region(CardLocation.previewRegion), search: .failing(.offline), query: "Local Roast", onAdd: { _ in })
        .environment(\.accessibilityAnnouncer, .silent)
}
#endif
