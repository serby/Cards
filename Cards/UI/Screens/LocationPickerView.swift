import MapKit
import SwiftUI

/// Picks a place for a card: drag the map under the pin, or jump to a postcode,
/// then set how far around it counts as "there".
public struct LocationPickerView: View {
    private let findPlace: (String) async -> PlaceMatch?
    private let onAppear: () -> Void
    private let onAdd: (CardLocation) -> Void

    @Environment(\.dismiss) private var dismiss
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

    private static let radiusRange: ClosedRange<CLLocationDistance> = 50...1_000

    public init(
        initialPosition: MapCameraPosition = .userLocation(fallback: .automatic),
        findPlace: @escaping (String) async -> PlaceMatch?,
        onAppear: @escaping () -> Void = {},
        onAdd: @escaping (CardLocation) -> Void
    ) {
        _position = State(initialValue: initialPosition)
        self.findPlace = findPlace
        self.onAppear = onAppear
        self.onAdd = onAdd
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                map
                pinAndRing
            }
            .safeAreaInset(edge: .bottom) { controls }
            .mapScope(mapScope)
                .navigationTitle(
                    Text("Add Location", comment: "Title of the map sheet for adding a place where a card is used.")
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel", comment: "Closes the Add Location sheet without adding a place.")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: add) {
                            Text("Add", comment: "Toolbar button that adds the place under the map pin to the card. A verb.")
                        }
                        .disabled(center == nil)
                        .accessibilityIdentifier("addLocationButton")
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
                    TextField(
                        "Postcode",
                        text: $postcode,
                        prompt: Text("Postcode", comment: "Placeholder in the search field that moves the map to a postcode or address.")
                    )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focusedField, equals: .postcode)
                    .onSubmit(search)
                    .accessibilityIdentifier("postcodeField")
                    if isSearching {
                        ProgressView()
                    } else if !postcode.isEmpty {
                        Button(action: search) {
                            Text("Find", comment: "Button beside the postcode field that moves the map to that postcode. A verb.")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .pickerField("magnifyingglass")

                MapUserLocationButton(scope: mapScope)
            }

            if notFound {
                Text(
                    "No place found for \u{201C}\(postcode)\u{201D}",
                    comment: "Under the postcode field when nothing is found. The argument is what was typed; use your language's quotation marks."
                )
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            TextField(
                "Name, e.g. Westway",
                text: $name,
                prompt: Text(
                    "Name, e.g. Westway",
                    comment: "Placeholder for the new place's name. Westway is a London climbing centre; a typical local place name may read better."
                )
            )
            .focused($focusedField, equals: .name)
            .pickerField("tag")
            .accessibilityIdentifier("locationNameField")

            VStack(spacing: 6) {
                HStack {
                    Text("Radius", comment: "Label above the slider that sets how far around the pin counts as being at the place.")
                    Spacer()
                    Text(radius.metres, format: .radius)
                        .monospacedDigit()
                        .foregroundStyle(Color.secondaryText)
                }
                .font(.subheadline)
                // The slider says both, so VoiceOver need not read them twice.
                .accessibilityHidden(true)
                Slider(value: $radius, in: Self.radiusRange, step: 25)
                    .accessibilityLabel(
                        Text("Radius", comment: "Label above the slider that sets how far around the pin counts as being at the place.")
                    )
                    .accessibilityValue(Text(radius.metres, format: .radius))
            }
        }
        .padding(18)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
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
            radius = CardLocation.defaultRadius
            if name.isEmpty { name = match.name }
            withAnimation {
                position = .region(
                    MKCoordinateRegion(center: match.coordinate, latitudinalMeters: 1_200, longitudinalMeters: 1_200)
                )
            }
        }
    }

    private func add() {
        guard let center else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        onAdd(
            CardLocation(
                // Saved with the card, so it is resolved to a String now.
                name: trimmed.isEmpty
                    ? String(localized: "Pinned location", comment: "Name saved for a place added on the map without typing a name.")
                    : trimmed,
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
