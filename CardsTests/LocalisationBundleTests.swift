import Foundation
import Testing

/// Every translation in the String Catalogues reaches the built app: each
/// language's `.lproj` has every key, in `Localizable` (`.strings` or
/// `.stringsdict`) and `InfoPlist`, and no empty value. `make l10n-check`
/// checks the catalogues; this checks what the build made of them, so a
/// language that drops out of the bundle, or a folder that comes up short,
/// fails here.
///
/// The keys come from the catalogues in the source tree, beside this file,
/// rather than from `en.lproj`: a catalogue compiles no strings for English
/// left as the source, so that folder holds only the English plural forms.
/// Every translation must have those too.
struct LocalisationBundleTests {
    /// The translations the bundle carries: every localisation but the
    /// development language and `Base`.
    static let languages: [String] = Bundle.main.localizations
        .filter { $0 != "Base" && $0 != Bundle.main.developmentLocalization }
        .sorted()

    @Test func theBundleHasEveryLanguageInTheCatalogues() throws {
        let localizable = try SourceCatalogue.load("Localizable")
        let infoPlist = try SourceCatalogue.load("InfoPlist")
        #expect(!localizable.languages.isEmpty, "The catalogue has no translations")
        #expect(Set(Self.languages) == localizable.languages.union(infoPlist.languages))
    }

    @Test(arguments: languages)
    func everyStringIsInTheBundle(_ language: String) throws {
        let catalogue = try SourceCatalogue.load("Localizable")
        let strings = Self.table("Localizable", "strings", in: language)
        let plurals = Self.table("Localizable", "stringsdict", in: language)
        let englishPlurals = Self.table("Localizable", "stringsdict", in: Bundle.main.developmentLocalization)
        #expect(!englishPlurals.isEmpty, "en.lproj has no plural forms")

        for key in catalogue.keys.union(englishPlurals.keys).sorted() {
            guard let value = strings[key] ?? plurals[key] else {
                Issue.record("\(language).lproj/Localizable has no \"\(key)\"")
                continue
            }
            #expect(Self.isFilled(value), "\(language).lproj/Localizable has an empty \"\(key)\"")
        }
    }

    @Test(arguments: languages)
    func everyInfoPlistStringIsInTheBundle(_ language: String) throws {
        let catalogue = try SourceCatalogue.load("InfoPlist")
        let strings = Self.table("InfoPlist", "strings", in: language)
        #expect(!catalogue.keys.isEmpty)

        for key in catalogue.keys.sorted() {
            guard let value = strings[key] else {
                Issue.record("\(language).lproj/InfoPlist has no \"\(key)\"")
                continue
            }
            #expect(Self.isFilled(value), "\(language).lproj/InfoPlist has an empty \"\(key)\"")
        }
    }

    // MARK: - Helpers

    /// A compiled table from the app bundle, or nothing if it is missing.
    private static func table(_ name: String, _ type: String, in language: String?) -> [String: Any] {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: type, subdirectory: nil, localization: language),
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

/// A String Catalogue in the source tree: the keys that must be translated,
/// and the languages it has translations for.
private struct SourceCatalogue {
    let keys: Set<String>
    let languages: Set<String>

    static func load(_ name: String, testFile: String = #filePath) throws -> Self {
        let url = URL(filePath: testFile)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(components: "Cards", "\(name).xcstrings")
        let file = try JSONDecoder().decode(CatalogueFile.self, from: Data(contentsOf: url))
        // Stale keys are no longer in the code, and untranslatable ones stay
        // in the source language.
        let entries = file.strings.filter { _, entry in
            entry.shouldTranslate && entry.extractionState != "stale"
        }
        let languages = entries.values.flatMap(\.localizations.keys)
        return Self(keys: Set(entries.keys), languages: Set(languages).subtracting([file.sourceLanguage]))
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

/// Only which languages an entry has matters here, not what they say.
private struct CatalogueLocalization: Decodable {}
