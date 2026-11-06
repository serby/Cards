import Foundation

/// Reads changelog.json, the file scripts/generate-changelog.ts generates
/// CHANGELOG.md and the App Store's What's New from, which the app bundles so
/// Settings can show it.
public enum ChangelogStore {
    /// The bundled changelog, newest version first, in the language the app is
    /// showing: a change's translation for that language and region where it
    /// has one, such as "es-MX", then for the language, such as "es", and
    /// otherwise its British English. English in the US reads "en-US" where a
    /// change has it. Empty if the file is missing or cannot be read.
    public static func bundled(_ bundle: Bundle = .main, locale: Locale = .current) -> [ChangelogVersion] {
        guard let url = bundle.url(forResource: "changelog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        let language = bundle.preferredLocalizations.first ?? "en"
        return (try? decode(data, textKeys: textKeys(language: language, region: locale.region?.identifier))) ?? []
    }

    /// Where to look for a change's text, most specific first: "es-MX" then "es"
    /// for Spanish in Mexico, "en-US" then "en" for English in the US.
    /// `language` is the app's localisation in use, such as "es" or "zh-Hant".
    /// A change with none of them shows its British English `text`.
    public static func textKeys(language: String, region: String?) -> [String] {
        [region.map { "\(language)-\($0)" }, language].compactMap(\.self)
    }

    public static func decode(_ data: Data, textKeys: [String]) throws -> [ChangelogVersion] {
        try JSONDecoder().decode(ChangelogFile.self, from: data).versions.map { version in
            ChangelogVersion(
                version: version.version,
                date: version.date.flatMap(day),
                // A kind this build does not know yet is left out, rather than the whole changelog.
                changes: version.changes.compactMap { change in
                    ChangelogChange.Kind(rawValue: change.type).map { kind in
                        let translated = textKeys.lazy.compactMap { change.translations[$0] }.first
                        return ChangelogChange(kind: kind, text: translated ?? change.text)
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

// changelog.json as written, before choosing each change's text.
private struct ChangelogFile: Decodable {
    let versions: [ChangelogFileVersion]
}

private struct ChangelogFileVersion: Decodable {
    let version: String
    let date: String?
    let changes: [ChangelogFileChange]
}

/// A change: its type, its British English text, and its other texts keyed by
/// language or locale ("en-US", "es", "es-MX", "de", "ja").
private struct ChangelogFileChange: Decodable {
    let type: String
    let text: String
    let translations: [String: String]

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            nil
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        type = try container.decode(String.self, forKey: Key(stringValue: "type"))
        text = try container.decode(String.self, forKey: Key(stringValue: "text"))
        var translations: [String: String] = [:]
        for key in container.allKeys where key.stringValue != "type" && key.stringValue != "text" {
            translations[key.stringValue] = try container.decode(String.self, forKey: key)
        }
        self.translations = translations
    }
}
