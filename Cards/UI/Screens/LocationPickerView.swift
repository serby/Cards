import MapKit
import SwiftUI

/// Picks a place for a card: drag the map under the pin, or jump to a postcode,
/// then set how far around it counts as "there". Adds a new place, or changes
/// one the card already has (PLACE-8).
public struct LocationPickerView: View {
    /// The place being changed, or nil when adding one.
    private let editing: CardLocation?
    private let findPlace: (String) async -> PlaceMatch?
    private let onAppear: () -> Void
    private let onConfirm: (CardLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.mapShowsPointsOfInterest) private var showsPointsOfInterest
    @State private var position: MapCameraPosition
    /// The point under the pin. Kept as plain values so an unchanged camera
    /// never invalidates the view (MapKit reports camera changes generously).
    @State private var center: MapPoint?
    @State private var metresPerPoint: Double?
    @State private var mapWidth: CGFloat = 0
    @State private var radius = CardLocation.defaultRadius
    @State private var name = ""
    @State private var postcode = ""
    @State private var isSearching = false
    @State private var notFound = false
    @FocusState private var focusedField: Field?
    @Namespace private var mapScope

    private enum Field {
        case postcode, name
    }

    private struct MapPoint: Equatable {
        let latitude: CLLocationDegrees
        let longitude: CLLocationDegrees
    }

    public init(
        initialPosition: MapCameraPosition = .userLocation(fallback: .automatic),
        findPlace: @escaping (String) async -> PlaceMatch?,
        onAppear: @escaping () -> Void = {},
        onAdd: @escaping (CardLocation) -> Void
    ) {
        self.init(position: initialPosition, editing: nil, findPlace: findPlace, onAppear: onAppear, onConfirm: onAdd)
    }

    /// Opens on `location` with its name and radius filled in, titled "Edit
    /// Location". Save hands back the changed place, with the same `id`.
    public init(
        editing location: CardLocation,
        findPlace: @escaping (String) async -> PlaceMatch?,
        onAppear: @escaping () -> Void = {},
        onSave: @escaping (CardLocation) -> Void
    ) {
        // Wide enough to show the whole ring round the pin, and never closer than adding opens.
        let span = max(800, location.radius * 4)
        self.init(
            position: .region(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: span, longitudinalMeters: span)),
            editing: location,
            findPlace: findPlace,
            onAppear: onAppear,
            onConfirm: onSave
        )
    }

    private init(
        position: MapCameraPosition,
        editing: CardLocation?,
        findPlace: @escaping (String) async -> PlaceMatch?,
        onAppear: @escaping () -> Void,
        onConfirm: @escaping (CardLocation) -> Void
    ) {
        _position = State(initialValue: position)
        if let editing {
            _name = State(initialValue: editing.name)
            _radius = State(initialValue: editing.radius)
            // The map reports its centre once it appears; until then it is the place's.
            _center = State(initialValue: MapPoint(latitude: editing.latitude, longitude: editing.longitude))
        }
        self.editing = editing
        self.findPlace = findPlace
        self.onAppear = onAppear
        self.onConfirm = onConfirm
    }

    /// Opens at `centre`, normally the user's last known location, or follows the
    /// user's location when there is none yet.
    public init(
        centre: CLLocationCoordinate2D?,
        findPlace: @escaping (String) async -> PlaceMatch?,
        onAppear: @escaping () -> Void = {},
        onAdd: @escaping (CardLocation) -> Void
    ) {
        self.init(
            initialPosition: centre.map { centre in
                .region(MKCoordinateRegion(center: centre, latitudinalMeters: 800, longitudinalMeters: 800))
            } ?? .userLocation(fallback: .automatic),
            findPlace: findPlace,
            onAppear: onAppear,
            onAdd: onAdd
        )
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                map
                pinAndRing
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

    private var pinAndRing: some View {
        ZStack {
            if let metresPerPoint {
                let diameter = 2 * radius / metresPerPoint
                Circle()
                    .fill(Color.accent.opacity(0.16))
                    .strokeBorder(Color.accent, lineWidth: 2)
                    .frame(width: diameter, height: diameter)
            }
            Image(systemName: "mappin")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.accent)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                // Lift the pin so its point, not its middle, marks the centre.
                .offset(y: -17)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    TextField("Postcode", text: $postcode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($focusedField, equals: .postcode)
                        .onSubmit(search)
                        .accessibilityIdentifier("postcodeField")
                    if isSearching {
                        ProgressView()
                    } else if !postcode.isEmpty {
                        Button("Find", action: search)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .pickerField("magnifyingglass")

                MapUserLocationButton(scope: mapScope)
            }

            if notFound {
                Text("No place found for \u{201C}\(postcode)\u{201D}")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            TextField("Name, e.g. Boulder Barn", text: $name)
                .focused($focusedField, equals: .name)
                .pickerField("tag")
                .accessibilityIdentifier("locationNameField")

            VStack(spacing: 6) {
                HStack {
                    Text("Radius")
                    Spacer()
                    Text(radiusText)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                Slider(value: $radius, in: CardLocation.radiusRange, step: 25)
                    .accessibilityLabel("Radius")
                    .accessibilityValue(radiusText)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var radiusText: String {
        radius.radiusText
    }

    private func search() {
        let query = postcode
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        focusedField = nil
        isSearching = true
        notFound = false
        Task {
            let match = await findPlace(query)
            isSearching = false
            guard let match else {
                notFound = true
                return
            }
            if name.isEmpty { name = match.name }
            withAnimation {
                position = .region(
                    MKCoordinateRegion(center: match.coordinate, latitudinalMeters: 1_200, longitudinalMeters: 1_200)
                )
            }
        }
    }

    /// Adds the place under the pin, or saves the changed one in place of the old.
    private func confirm() {
        guard let center else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        onConfirm(
            CardLocation(
                id: editing?.id ?? UUID(),
                name: trimmed.isEmpty ? "Pinned location" : trimmed,
                latitude: center.latitude,
                longitude: center.longitude,
                radius: radius
            )
        )
        dismiss()
    }
}

private extension View {
    /// A text field row in the picker panel: leading icon, system fill, and
    /// room to grow with Dynamic Type.
    func pickerField(_ systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            self
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color(UIColor.tertiarySystemFill), in: .rect(cornerRadius: 12))
    }
}

#if DEBUG
#Preview {
    LocationPickerView(
        initialPosition: .region(CardLocation.previewRegion),
        findPlace: { _ in nil },
        onAdd: { _ in }
    )
}
#endif
