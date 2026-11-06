import SwiftUI

/// What's New: every version and what it changed, newest first, from
/// changelog.json. Opened from Settings.
public struct ChangelogView: View {
    private let versions: [ChangelogVersion]

    public init(versions: [ChangelogVersion]) {
        self.versions = versions
    }

    public var body: some View {
        List {
            ForEach(versions) { version in
                Section {
                    ForEach(Array(version.changes.enumerated()), id: \.offset) { _, change in
                        ChangeRow(change: change)
                    }
                } header: {
                    VersionHeader(version: version)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if versions.isEmpty {
                ContentUnavailableView(
                    LocalizedStringResource(
                        "No Changes Yet",
                        comment: "Shown on the What's New screen when the app has no list of changes to show."
                    ),
                    systemImage: "sparkles"
                )
            }
        }
        .navigationTitle(
            Text("What's New", comment: "Title of the screen, opened from Settings, that lists what each version of the app changed.")
        )
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("changelogView")
    }
}

private struct VersionHeader: View {
    let version: ChangelogVersion

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(
                "Version \(version.version)",
                comment: "Heading for one version of the app on the What's New screen. The argument is its number, as in “1.4”."
            )
                .font(.headline)
                .foregroundStyle(Color.primaryText)
            Spacer()
            if let date = version.date {
                Text(date, format: .dateTime.day().month(.wide).year())
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct ChangeRow: View {
    let change: ChangelogChange

    var body: some View {
        Label {
            Text(change.text)
                .foregroundStyle(Color.primaryText)
        } icon: {
            Image(systemName: change.kind.symbol)
                .foregroundStyle(Color.accent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(change.kind.spokenLabel(change.text))
    }
}

extension ChangelogChange.Kind {
    /// What VoiceOver reads for a change of this kind: its kind, which the
    /// icon shows, then its words, which come from the changelog as written.
    func spokenLabel(_ text: String) -> Text {
        switch self {
        case .new:
            Text(
                "New: \(text)",
                comment: """
                    VoiceOver label for a change on the What's New screen that adds something to the app. \
                    The argument is the change in its own words, as the changelog has it.
                    """
            )
        case .improved:
            Text(
                "Improved: \(text)",
                comment: """
                    VoiceOver label for a change on the What's New screen that makes something in the app better. \
                    The argument is the change in its own words, as the changelog has it.
                    """
            )
        case .fixed:
            Text(
                "Fixed: \(text)",
                comment: """
                    VoiceOver label for a change on the What's New screen that fixes a problem in the app. \
                    The argument is the change in its own words, as the changelog has it.
                    """
            )
        }
    }

    var symbol: String {
        switch self {
        case .new:
            "sparkles"
        case .improved:
            "arrow.up.circle"
        case .fixed:
            "wrench.and.screwdriver"
        }
    }
}

#if DEBUG
#Preview("Two versions") {
    NavigationStack {
        ChangelogView(versions: ChangelogVersion.samples)
    }
}

#Preview("Empty") {
    NavigationStack {
        ChangelogView(versions: [])
    }
}
#endif
