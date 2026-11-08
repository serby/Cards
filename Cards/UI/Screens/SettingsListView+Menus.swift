import SwiftUI

/// The menus in Settings > Locations: Distances (SET-4) and Maps (SET-5).
extension SettingsListView {
    var distanceUnitsMenu: some View {
        choiceMenu(
            Text(
                "Distances",
                comment: "Settings menu for the units distances and radii are shown in: Automatic, Kilometres or Miles."
            ),
            selection: $distanceUnits,
            choices: DistanceUnits.allCases,
            identifier: "distanceUnitsPicker"
        ) { units in
            Text(units.title(for: locale))
        }
    }

    /// The Maps menu and its caption.
    @ViewBuilder
    var mapsAppRows: some View {
        choiceMenu(
            Text("Maps", comment: "Settings menu for the app a card's places open in: Apple Maps or Google Maps."),
            selection: $mapsApp,
            choices: MapsApp.allCases,
            identifier: "mapsAppPicker"
        ) { app in
            Text(app.title)
        }
        Text(
            "Where a card's places open when you tap one. Google Maps opens in your browser if its app isn't installed.",
            comment: "Under the Maps menu in Settings. Google Maps is Google's app; use the name Google gives it in your language."
        )
        .font(.caption)
        .foregroundStyle(Color.secondaryText)
        .accessibilityIdentifier("mapsAppFooter")
    }

    /// A menu of `choices`: its title and the choice side by side, or the
    /// choice under the title at accessibility sizes, wrapping. The system's
    /// menu picker cut its value off there ("Auto…Miles)" on iOS 26.5), so this
    /// is a menu of the same choices with a label of its own. VoiceOver reads it
    /// as it read the picker: the title, then the choice as its value. Each
    /// choice is identified by `identifier` and its stored value, such as
    /// `distanceUnitsPicker_miles`, so UI tests find it in any language.
    func choiceMenu<Choice: Hashable & RawRepresentable<String>>(
        _ title: Text,
        selection: Binding<Choice>,
        choices: [Choice],
        identifier: String,
        label: @escaping (Choice) -> Text
    ) -> some View {
        let value = label(selection.wrappedValue)
        return Menu {
            Picker(selection: selection) {
                ForEach(choices, id: \.self) { choice in
                    label(choice)
                        .tag(choice)
                        .accessibilityIdentifier("\(identifier)_\(choice.rawValue)")
                }
            } label: {
                title
            }
        } label: {
            rowLayout {
                title
                    .foregroundStyle(Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    value
                        .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                }
                .foregroundStyle(Color.accent)
            }
        }
        .tint(.accent)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityIdentifier(identifier)
    }
}
