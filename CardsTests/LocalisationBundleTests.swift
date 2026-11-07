import Foundation
import Testing

/// Every translation in the String Catalogues reaches the built app and its
/// widget: each language's `.lproj` in each bundle has every key, in
/// `Localizable` (`.strings` or `.stringsdict`) and `InfoPlist`, and no empty
/// value. `make check-strings` checks the catalogues; this checks what the build
/// made of them, so a language that drops out of a bundle, or a folder that
/// comes up short, fails here.
///
/// The keys come from the catalogues in the source tree, beside this file,
/// rather than from `en.lproj`: a catalogue compiles no strings for English
/// left as the source, so that folder holds only the English plural forms.
/// Every translation must have those too.
struct LocalisationBundleTests {
    /// The translations the app carries: every localisation but the
    /// development language and `Base`. The widget must carry the same.
    static let languages: [String] = Bundle.main.localizations
        .filter { $0 != "Base" && $0 != Bundle.main.developmentLocalization }
        .sorted()

    @Test(arguments: ShippedBundle.allCases)
    func theBundleHasEveryLanguageInTheCatalogues(_ shipped: ShippedBundle) throws {
        let bundle = try #require(shipped.bundle, "\(shipped) is not in the app")
        let localizable = try SourceCatalogue.load("Localizable", in: shipped)
        let infoPlist = try SourceCatalogue.load("InfoPlist", in: shipped)
        let languages = bundle.localizations.filter { $0 != "Base" && $0 != bundle.developmentLocalization }
        #expect(!localizable.languages.isEmpty, "The catalogue has no translations")
        #expect(Set(languages) == localizable.languages.union(infoPlist.languages))
        #expect(Set(languages) == Set(Self.languages), "\(shipped) has other languages from the app")
    }

    @Test(arguments: ShippedBundle.allCases, languages)
    func everyStringIsInTheBundle(_ shipped: ShippedBundle, _ language: String) throws {
        let bundle = try #require(shipped.bundle, "\(shipped) is not in the app")
        let catalogue = try SourceCatalogue.load("Localizable", in: shipped)
        let strings = Self.table("Localizable", "strings", in: language, of: bundle)
        let plurals = Self.table("Localizable", "stringsdict", in: language, of: bundle)
        let englishPlurals = Self.table("Localizable", "stringsdict", in: bundle.developmentLocalization, of: bundle)
        if catalogue.hasPlurals {
            #expect(!englishPlurals.isEmpty, "en.lproj has no plural forms")
        }

        for key in catalogue.keys.union(englishPlurals.keys).sorted() {
            guard let value = strings[key] ?? plurals[key] else {
                Issue.record("\(shipped): \(language).lproj/Localizable has no \"\(key)\"")
                continue
            }
            #expect(Self.isFilled(value), "\(shipped): \(language).lproj/Localizable has an empty \"\(key)\"")
        }
    }

    @Test(arguments: ShippedBundle.allCases, languages)
    func everyInfoPlistStringIsInTheBundle(_ shipped: ShippedBundle, _ language: String) throws {
        let bundle = try #require(shipped.bundle, "\(shipped) is not in the app")
        let catalogue = try SourceCatalogue.load("InfoPlist", in: shipped)
        let strings = Self.table("InfoPlist", "strings", in: language, of: bundle)
        #expect(!catalogue.keys.isEmpty)

        for key in catalogue.keys.sorted() {
            guard let value = strings[key] else {
                Issue.record("\(shipped): \(language).lproj/InfoPlist has no \"\(key)\"")
                continue
            }
            #expect(Self.isFilled(value), "\(shipped): \(language).lproj/InfoPlist has an empty \"\(key)\"")
        }
    }

    // MARK: - Helpers

    /// A compiled table from a bundle, or nothing if it is missing.
    private static func table(_ name: String, _ type: String, in language: String?, of bundle: Bundle) -> [String: Any] {
        guard
            let url = bundle.url(forResource: name, withExtension: type, subdirectory: nil, localization: language),
            let data = try? Data(contentsOf: url),
            let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return table
    }

    /// A string with something in it, or a plural entry whose every form has.
    private static func isFilled(_ value: Any) -> Bool {
        switch value {
        case let string as String:
            !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case let entry as [String: Any]:
            !entry.isEmpty && entry.values.allSatisfy(isFilled)
        default:
            false
        }
    }
}

/// A bundle the app ships, each with its own catalogues: the app's, built
/// from those under `Cards/`, and the Home Screen widget's, inside the app's
/// `PlugIns` and built from those under `CardsWidget/`.
enum ShippedBundle: String, CaseIterable, CustomTestStringConvertible, Sendable {
    case app
    case widget

    var bundle: Bundle? {
        switch self {
        case .app:
            Bundle.main
        case .widget:
            Bundle.main.builtInPlugInsURL.flatMap { Bundle(url: $0.appending(path: "CardsWidget.appex")) }
        }
    }

    /// The folder in the source tree holding its catalogues.
    var sourceFolder: String {
        switch self {
        case .app:
            "Cards"
        case .widget:
            "CardsWidget"
        }
    }

    var testDescription: String { rawValue }
}

/// A String Catalogue in the source tree: the keys that must be translated,
/// and the languages it has translations for.
private struct SourceCatalogue {
    let keys: Set<String>
    let languages: Set<String>
    /// Whether any of the keys has plural forms, which compile to
    /// `en.lproj/Localizable.stringsdict` even in English.
    let hasPlurals: Bool

    static func load(_ name: String, in shipped: ShippedBundle, testFile: String = #filePath) throws -> Self {
        let url = URL(filePath: testFile)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(components: shipped.sourceFolder, "\(name).xcstrings")
        let file = try JSONDecoder().decode(CatalogueFile.self, from: Data(contentsOf: url))
        // Stale keys are no longer in the code, and untranslatable ones stay
        // in the source language.
        let entries = file.strings.filter { _, entry in
            entry.shouldTranslate && entry.extractionState != "stale"
        }
        let languages = entries.values.flatMap(\.localizations.keys)
        return Self(
            keys: Set(entries.keys),
            languages: Set(languages).subtracting([file.sourceLanguage]),
            hasPlurals: entries.values.contains { $0.localizations[file.sourceLanguage]?.variations?.isPlural == true }
        )
    }
}

private struct CatalogueFile: Decodable {
    let sourceLanguage: String
    let strings: [String: CatalogueEntry]
}

/// A catalogue leaves out what is the default: translatable, extracted, no
/// translations.
private struct CatalogueEntry: Decodable {
    let shouldTranslate: Bool
    let extractionState: String?
    let localizations: [String: CatalogueLocalization]

    private enum CodingKeys: String, CodingKey {
        case shouldTranslate, extractionState, localizations
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shouldTranslate = try container.decodeIfPresent(Bool.self, forKey: .shouldTranslate) ?? true
        extractionState = try container.decodeIfPresent(String.self, forKey: .extractionState)
        localizations = try container.decodeIfPresent([String: CatalogueLocalization].self, forKey: .localizations) ?? [:]
    }
}

/// Only which languages an entry has matters here, and whether its source has
/// plural forms, not what they say.
private struct CatalogueLocalization: Decodable {
    let variations: CatalogueVariations?
}

private struct CatalogueVariations: Decodable {
    /// Whether the source has plural forms; what they say does not matter.
    let isPlural: Bool

    private enum CodingKeys: String, CodingKey {
        case plural
    }

    init(from decoder: any Decoder) throws {
        isPlural = try decoder.container(keyedBy: CodingKeys.self).contains(.plural)
    }
}
