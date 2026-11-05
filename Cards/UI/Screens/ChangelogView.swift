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
                ContentUnavailableView("No Changes Yet", systemImage: "sparkles")
            }
        }
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("changelogView")
    }
}

private struct VersionHeader: View {
    let version: ChangelogVersion

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Version \(version.version)")
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
        .accessibilityLabel("\(change.kind.label): \(change.text)")
    }
}

extension ChangelogChange.Kind {
    var label: String {
        switch self {
        case .new:
            "New"
        case .improved:
            "Improved"
        case .fixed:
            "Fixed"
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
