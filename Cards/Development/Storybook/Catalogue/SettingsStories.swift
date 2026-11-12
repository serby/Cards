import SwiftUI

@MainActor
let settingsStory = Story(
    id: "settings",
    title: "SettingsListView",
    section: "Screens",
    galleryLayout: .oneAtATime,
    knobs: [
        .text("Version", "1.1"),
        .text("Build", "42"),
        .text("Author", "Paul Serby"),
        .text("Author URL", "https://github.com/serby"),
        .number("Card count", 6, in: 0...50, step: 1),
        .toggle("Brightness boost", true),
        .toggle("Arrival notifications", true),
        .toggle("Show card where I am", false),
        .toggle("Notifications blocked", false),
        .toggle("Has What's New", true),
        .toggle("iCloud sync", true),
        .options("iCloud status", ICloudSyncSample.allCases.map(\.rawValue), ICloudSyncSample.upToDate.rawValue),
        .options("iCloud deletion", ICloudDeletion.allCases.map(\.rawValue), ICloudDeletion.notAsked.rawValue),
        .toggle("Share diagnostics", true),
        .options("Maps app", MapsApp.allCases.map(\.rawValue), MapsApp.appleMaps.rawValue),
        .text("Message", "")
    ] + DistanceKnobs.knobs,
    gallery: [
        (
            name: "With cards",
            view: pushed {
                Stateful(true) { boost in
                    SettingsListView(state: .sample, brightnessBoost: boost)
                }
            }
        ),
        (
            name: "No cards",
            view: pushed {
                Stateful(false) { boost in
                    SettingsListView(state: .noCards, brightnessBoost: boost)
                }
            }
        ),
        (
            name: "Notifications blocked",
            view: pushed {
                Stateful(true) { arrivals in
                    SettingsListView(state: .withNotificationsBlocked, brightnessBoost: .constant(true), arrivalNotifications: arrivals)
                }
            }
        ),
        (
            name: "Not signed in to iCloud",
            view: pushed {
                Stateful(true) { boost in
                    SettingsListView(state: .notSignedInToICloud, brightnessBoost: boost)
                }
            }
        ),
        (
            name: "Distances in miles",
            view: pushed {
                Stateful(DistanceUnits.miles) { units in
                    SettingsListView(state: .sample, brightnessBoost: .constant(true), distanceUnits: units)
                }
            }
        )
    ]
) { knobs in
    let state = SettingsState(
        appVersion: knobs.string("Version"),
        appBuild: knobs.string("Build"),
        authorName: knobs.string("Author"),
        authorURL: URL(string: knobs.string("Author URL")),
        cardCount: knobs.integer("Card count"),
        notificationsBlocked: knobs.bool("Notifications blocked"),
        changelog: knobs.bool("Has What's New") ? ChangelogVersion.samples : [],
        iCloudDeletion: ICloudDeletion(rawValue: knobs.string("iCloud deletion")) ?? .notAsked,
        iCloudSync: (ICloudSyncSample(rawValue: knobs.option("iCloud status")) ?? .upToDate).status
    )
    // An empty Message knob means no alert. The knob's text is shown as it is.
    let message = Binding<String?>(
        get: { knobs.string("Message").isEmpty ? nil : knobs.string("Message") },
        set: { knobs.set($0 ?? "", for: "Message") }
    )
    return pushed {
        SettingsListView(
            state: state,
            brightnessBoost: knobs.boolBinding("Brightness boost"),
            arrivalNotifications: knobs.boolBinding("Arrival notifications"),
            showsCardWhereYouAre: knobs.boolBinding("Show card where I am"),
            distanceUnits: knobs.distanceUnitsBinding,
            mapsApp: knobs.optionBinding("Maps app", default: MapsApp.appleMaps),
            syncsWithICloud: knobs.boolBinding("iCloud sync"),
            sharesDiagnostics: knobs.boolBinding("Share diagnostics"),
            message: message
        )
        .distances(knobs)
    }
}
