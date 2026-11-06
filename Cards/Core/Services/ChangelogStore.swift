import Foundation

/// Reads changelog.json, the file scripts/generate-changelog.ts generates
/// CHANGELOG.md and the App Store's What's New from, which the app bundles so
/// Settings can show it.
public enum ChangelogStore {
    /// The bundled changelog, newest version first, in the English the user reads:
    /// American where an entry has an "en-US" text and the region is the US.
    /// Empty if the file is missing or cannot be read.
    public static func bundled(_ bundle: Bundle = .main, locale: Locale = .current) -> [ChangelogVersion] {
        guard let url = bundle.url(forResource: "changelog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? decode(data, americanEnglish: locale.region == .unitedStates)) ?? []
    }

    public static func decode(_ data: Data, americanEnglish: Bool) throws -> [ChangelogVersion] {
        try JSONDecoder().decode(ChangelogFile.self, from: data).versions.map { version in
            ChangelogVersion(
                version: version.version,
                date: version.date.flatMap(day),
                // A kind this build does not know yet is left out, rather than the whole changelog.
                changes: version.changes.compactMap { change in
                    ChangelogChange.Kind(rawValue: change.type).map { kind in
                        ChangelogChange(kind: kind, text: americanEnglish ? change.american ?? change.text : change.text)
                    }
                }
            )
        }
    }

    /// Midday UTC on a YYYY-MM-DD day, so the date reads the same in every time zone.
    private static func day(_ text: String) -> Date? {
        try? Date("\(text)T12:00:00Z", strategy: .iso8601)
    }
}

// changelog.json as written, before choosing each change's English.
private struct ChangelogFile: Decodable {
    let versions: [ChangelogFileVersion]
}

private struct ChangelogFileVersion: Decodable {
    let version: String
    let date: String?
    let changes: [ChangelogFileChange]
}

private struct ChangelogFileChange: Decodable {
    let type: String
    let text: String
    let american: String?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case american = "en-US"
    }
}
