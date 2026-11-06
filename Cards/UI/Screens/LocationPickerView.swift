import MapKit
import SwiftUI

/// Picks a place for a card: search for it, or drag the map under the pin,
/// then set how far around it counts as "there". MapKit names the place until
/// you type a name of your own (PLACE-10). Adds a new place, or changes one the
/// card already has (PLACE-8).
public struct LocationPickerView: View {
    /// The place being changed, or nil when adding one.
    private let editing: CardLocation?
    private let search: PlaceSearch
    private let onAppear: () -> Void
    private let onConfirm: (CardLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.mapShowsPointsOfInterest) private var showsPointsOfInterest
    @Environment(\.accessibilityAnnouncer) private var announcer
    @State private var position: MapCameraPosition
    /// The point under the pin. Kept as plain values so an unchanged camera
    /// never invalidates the view (MapKit reports camera changes generously).
    @State private var center: MapPoint?
    @State private var metresPerPoint: Double?
    @State private var mapWidth: CGFloat = 0
    @State private var radius = CardLocation.defaultRadius
    @State private var name: PlaceNameDraft
    @State private var query: String
    /// Whether the panel lists suggestions in place of the name and radius:
    /// from typing in the search field until a place is chosen or it is cleared.
    @State private var showsSuggestions: Bool
    @State private var results = PlaceSearchStatus.searching
    @State private var isSuggesting = false
    /// Finding the place a suggestion, or return, stands for.
    @State private var isFinding = false
    /// Why the last place looked for was not found, shown below the search field.
    @State private var findProblem: PlaceSearchStatus?
    @FocusState private var focusedField: Field?
    @Namespace private var mapScope

    private enum Field {
        case search, name
    }

    private struct MapPoint: Equatable {
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
            }
            .safeAreaInset(edge: .bottom) { controls }
            .mapScope(mapScope)
                .navigationTitle(editing == nil ? "Add Location" : "Edit Location")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(editing == nil ? "Add" : "Save", action: confirm)
                            .disabled(center == nil)
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

                TextField("Name, e.g. Boulder Barn", text: Binding(get: { name.text }, set: { name.type($0) }))
                    .focused($focusedField, equals: .name)
                    .pickerField("tag")
                    .accessibilityLabel("Place name")
                    .accessibilityIdentifier("locationNameField")

                RadiusSlider(radius: $radius)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            TextField("Search for a place", text: Binding(get: { query }, set: edit))
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focusedField, equals: .search)
                .onSubmit(findBestMatch)
                .accessibilityLabel("Search for a place")
                .accessibilityHint("Finds shops, addresses, streets, towns and postcodes")
                .accessibilityIdentifier("placeSearchField")
            if isFinding || (showsSuggestions && isSuggesting) {
                ProgressView()
                    .accessibilityLabel("Searching")
            } else if !query.isEmpty {
                Button("Clear Search", systemImage: "xmark.circle.fill", action: clearSearch)
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
    private var mapWidthInMetres: Double? {
        metresPerPoint.map { $0 * mapWidth }
    }

    /// The map on screen, which searches lean towards. Before the map has
    /// reported its size, the 800 metres it opens at round its centre.
    private var searchRegion: MKCoordinateRegion? {
        guard let center else { return nil }
        let width = mapWidthInMetres ?? 800
        return MKCoordinateRegion(center: center.coordinate, latitudinalMeters: width, longitudinalMeters: width)
    }

    // MARK: - Searching

    /// The person typed in the search field. The field writes its text back
    /// when it loses focus, as it does once a place is chosen; the same text
    /// again is no typing, so the list stays closed.
    private func edit(_ text: String) {
        guard text != query else { return }
        query = text
        showsSuggestions = !text.trimmed.isEmpty
        findProblem = nil
    }

    private func clearSearch() {
        query = ""
        showsSuggestions = false
        findProblem = nil
    }

    /// Suggestions for the search text, once typing pauses.
    private func suggest() async {
        let text = query.trimmed
        guard showsSuggestions, !text.isEmpty else {
            isSuggesting = false
            return
        }
        // The last suggestions stay while the next arrive, so the list does not flicker.
        if case .found = results {} else { results = .searching }
        isSuggesting = true
        do {
            try await Task.sleep(for: .milliseconds(250))
            results = .answer(try await search.suggest(text, searchRegion), to: text)
        } catch is CancellationError {
            return
        } catch {
            results = .failure(error)
        }
        isSuggesting = false
    }

    private func choose(_ suggestion: PlaceSuggestion) {
        query = suggestion.title
        find(describing: suggestion.title) { try await search.place(suggestion, searchRegion) }
    }

    /// Return pressed: the best match for the text, chosen or not.
    private func findBestMatch() {
        let text = query.trimmed
        guard !text.isEmpty else { return }
        find(describing: text) { try await search.bestMatch(text, searchRegion) }
    }

    private func find(describing text: String, _ lookUp: @escaping @MainActor () async throws -> PlaceMatch?) {
        focusedField = nil
        showsSuggestions = false
        findProblem = nil
        isFinding = true
        Task {
            defer { isFinding = false }
            do {
                guard let match = try await lookUp() else {
                    report(.notFound(text))
                    return
                }
                name.name(match.name, at: match.coordinate)
                withAnimation {
                    position = .region(
                        MKCoordinateRegion(center: match.coordinate, latitudinalMeters: 1_200, longitudinalMeters: 1_200)
                    )
                }
                announcer.announce("Showing \(match.name) on the map")
            } catch is CancellationError {
                return
            } catch {
                report(.failure(error))
            }
        }
    }

    private func report(_ problem: PlaceSearchStatus) {
        findProblem = problem
        if let message = problem.message {
            announcer.announce(message)
        }
    }

    // MARK: - Naming

    /// Names the place under the pin from MapKit once the map comes to rest,
    /// unless the name is the person's own or the pin was only nudged (PLACE-10).
    private func nameThePlaceUnderThePin() async {
        guard let point = center?.coordinate, name.needsName(at: point, mapWidth: mapWidthInMetres) else { return }
        do {
            try await Task.sleep(for: .milliseconds(600))
            let placeName = try? await search.name(point)
            try Task.checkCancellation()
            name.name(placeName, at: point)
        } catch {
            // The map moved again; the next rest asks again.
        }
    }

    /// Adds the place under the pin, or saves the changed one in place of the old.
    private func confirm() {
        guard let center else { return }
        onConfirm(
            CardLocation(
                id: editing?.id ?? UUID(),
                name: name.savedName,
                latitude: center.latitude,
                longitude: center.longitude,
                radius: radius
            )
        )
        dismiss()
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
