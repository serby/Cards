import MapKit
import SwiftUI

// The picker's searching, naming and words, beside LocationPickerView.swift
// so each file stays readable. Internal rather than private only so the two
// files share them.

// MARK: - Searching

extension LocationPickerView {
    /// The person typed in the search field. The field writes its text back
    /// when it loses focus, as it does once a place is chosen; the same text
    /// again is no typing, so the list stays closed.
    func edit(_ text: String) {
        guard text != query else { return }
        query = text
        showsSuggestions = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        findProblem = nil
    }

    func clearSearch() {
        query = ""
        showsSuggestions = false
        findProblem = nil
    }

    /// Suggestions for the search text, once typing pauses.
    func suggest() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
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

    func choose(_ suggestion: PlaceSuggestion) {
        query = suggestion.title
        find(describing: suggestion.title) { try await search.place(suggestion, searchRegion) }
    }

    /// Return pressed: the best match for the text, chosen or not.
    func findBestMatch() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        find(describing: text) { try await search.bestMatch(text, searchRegion) }
    }

    /// Both results are spoken, as the map's move and the message are otherwise silent.
    func find(describing text: String, _ lookUp: @escaping @MainActor () async throws -> PlaceMatch?) {
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
                withAnimation(mapAnimation) {
                    position = .region(
                        MKCoordinateRegion(center: match.coordinate, latitudinalMeters: 1_200, longitudinalMeters: 1_200)
                    )
                }
                announcer.announce(
                    String(
                        localized: "Showing \(match.name) on the map",
                        comment: "VoiceOver announcement once a search moves the location map to a place. The argument is the place's name."
                    )
                )
            } catch is CancellationError {
                return
            } catch {
                report(.failure(error))
            }
        }
    }

    func report(_ problem: PlaceSearchStatus) {
        findProblem = problem
        if let message = problem.message {
            announcer.announce(String(localized: message))
        }
    }
}

// MARK: - Naming

extension LocationPickerView {
    /// Names the place under the pin from MapKit once the map comes to rest,
    /// unless the name is the person's own or the pin was only nudged (PLACE-10).
    func nameThePlaceUnderThePin() async {
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
    func confirm() {
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

// MARK: - Accessibility and words

extension LocationPickerView {
    /// The map flies to a new place, unless Reduce Motion is on, when it cuts
    /// straight there: a long camera move is the motion that setting stops.
    var mapAnimation: Animation? {
        reduceMotion ? nil : .default
    }

    /// Moves the map, and so the place under the pin, one radius `direction`,
    /// keeping the map's width. It moves only the camera, never the map's
    /// content (rule 7).
    func nudge(_ direction: Compass) {
        guard let center else { return }
        let target = direction.moving(center.coordinate, by: radius)
        let width = mapWidthInMetres ?? 800
        withAnimation(mapAnimation) {
            position = .region(MKCoordinateRegion(center: target, latitudinalMeters: width, longitudinalMeters: width))
        }
        announcer.announce(direction.announcement)
    }

    /// The name field's text. Return ends editing, and is no typing: its line
    /// break stays for one update, so the field lays out again (as with
    /// `singleLine`), then the draft goes back to what it was, so a name from
    /// MapKit stays MapKit's (PLACE-10). A pasted line break is dropped.
    var nameText: Binding<String> {
        Binding(
            get: { name.text },
            set: { text in
                let draft = name
                name.type(text)
                guard text.contains(where: \.isNewline) else { return }
                Task { @MainActor in
                    name = draft
                    name.type(text.filter { !$0.isNewline })
                    focusedField = nil
                }
            }
        )
    }

    var searchPrompt: Text {
        Text("Search for a place", comment: "Placeholder and VoiceOver label of the search field on the location map.")
    }

    var placeNameLabel: Text {
        Text("Place name", comment: "VoiceOver label of the name field on the location map, read before the name in it.")
    }

    var namePrompt: Text {
        Text(
            "Name, e.g. Boulder Barn",
            comment: """
                Placeholder in the empty name field on the location map. \
                Boulder Barn is a made-up climbing centre: keep the name Boulder Barn and translate only “Name, e.g.”.
                """
        )
    }

    var clearSearchTitle: LocalizedStringResource {
        LocalizedStringResource("Clear Search", comment: "VoiceOver label of the button that empties the location map's search field.")
    }
}
