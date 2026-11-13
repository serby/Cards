// Tests for scripts/lib/string-catalogues.ts. Run with: node --test scripts/string-catalogues.test.ts
//
// fixtures/string-catalogues/format/xcode-saved.xcstrings was written by Xcode
// 27.1 itself: a copy of the app's catalogue seeded with awkward keys and
// values (emoji, NFD, control characters, slashes, numbers, mixed case,
// language codes whose order differs between collations), re-saved by
// `xcodebuild -exportLocalizations`. The pbxproj fixtures are the app's
// project file just before and just after the ten target languages were added.

import assert from "node:assert/strict";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join, relative } from "node:path";
import { describe, test } from "node:test";

import { catalogueOf, fixtures, projectWithWidget, scramble, unit } from "./fixtures/string-catalogues/test-project.ts";
import {
    addKnownRegion,
    assess,
    canonicalLanguage,
    checkReport,
    compareKeys,
    findCatalogues,
    formatCatalogue,
    formatJSON,
    languageName,
    parseCatalogue,
    placeholders,
    pluralCategories,
    projectAt,
    projectLanguages,
    readKnownRegions,
    removeKnownRegion,
    removeLanguage,
    requiredPluralCategories,
    restoreLanguage,
    singleNumber,
    type Text,
    unitsOf,
    validate,
} from "./lib/string-catalogues.ts";

describe("Xcode's file format", () => {
    const saved = readFileSync(join(fixtures, "format", "xcode-saved.xcstrings"), "utf8");

    test("an Xcode-saved catalogue round-trips byte for byte", () => {
        assert.equal(formatCatalogue(parseCatalogue(saved, "fixture")), saved);
    });

    test("compact, unsorted JSON with Xcode's dropped defaults formats to what Xcode wrote", () => {
        const doc = parseCatalogue(saved, "fixture");
        doc.strings["Language order"].shouldTranslate = true;
        doc.strings["Cancel"].localizations = {};
        doc.strings["Empty substitutions"].localizations!.de.substitutions = {};
        const messy = JSON.stringify(scramble(doc));
        assert.notEqual(messy, saved);
        assert.equal(formatCatalogue(parseCatalogue(messy, "messy")), saved);
    });

    test("details Xcode is particular about", () => {
        assert.equal(formatJSON({}), "{\n\n}");
        assert.equal(formatJSON({ a: { b: [] } }), '{\n  "a" : {\n    "b" : [\n\n    ]\n  }\n}');
        assert.equal(formatJSON({ s: "a/b é 🎉   \u007f" }), '{\n  "s" : "a/b é 🎉   \u007f"\n}');
        assert.equal(formatJSON({ s: "\u0001\t\n\"\\" }), '{\n  "s" : "\\u0001\\t\\n\\"\\\\"\n}');
        assert.ok(!saved.endsWith("\n"), "Xcode writes no final newline");
    });

    test("keys sort like Xcode's editor: case-insensitive, numbers by value, at every level", () => {
        const sorted = ["10 items", "2 items", "apple", "Apple", "zh-HK", "zh-Hans", "Barcode Type", "Barcode type", "_x", "Zebra"].sort(compareKeys);
        assert.deepEqual(sorted, ["_x", "2 items", "10 items", "apple", "Apple", "Barcode type", "Barcode Type", "Zebra", "zh-Hans", "zh-HK"]);
    });
});

describe("plural rules", () => {
    test("come from Intl, in CLDR order", () => {
        assert.deepEqual(pluralCategories("ar"), ["zero", "one", "two", "few", "many", "other"]);
        assert.deepEqual(pluralCategories("ja"), ["other"]);
        assert.deepEqual(pluralCategories("pt-BR"), ["one", "many", "other"]);
    });

    test("a source that spells out zero keeps it in every language", () => {
        assert.deepEqual(requiredPluralCategories("ja", ["zero", "one", "other"]), ["zero", "other"]);
        assert.deepEqual(requiredPluralCategories("pt-BR", ["one", "other"]), ["one", "many", "other"]);
    });

    test("validation needs exactly the language's categories", () => {
        const source: Text = { plural: { one: "%lld card", other: "%lld cards" } };
        assert.deepEqual(validate(source, { plural: { other: "%lld 枚" } }, "ja"), []);
        assert.deepEqual(validate(source, { plural: { one: "%lld carta", many: "%lld de cartas", other: "%lld cartas" } }, "pt-BR"), []);
        const missing = validate(source, { plural: { one: "%lld carta", other: "%lld cartas" } }, "pt-BR");
        assert.deepEqual(missing.map((p) => [p.kind, p.message]), [["missing", "missing plural category many"]]);
        const extra = validate(source, { plural: { one: "%lld 枚", other: "%lld 枚" } }, "ja");
        assert.deepEqual(extra.map((p) => p.kind), ["invalid"]);
        const arabic = { zero: "لا بطاقات %lld", one: "%lld بطاقة", two: "%lld بطاقتان", few: "%lld بطاقات", many: "%lld بطاقة", other: "%lld بطاقة" };
        assert.deepEqual(validate(source, { plural: arabic }, "ar"), []);
        const { two: _two, ...noTwo } = arabic;
        assert.match(validate(source, { plural: noTwo }, "ar")[0].message, /missing plural category two/);
    });

    test("each form keeps the placeholders", () => {
        const source: Text = { plural: { one: "One card", other: "%lld cards" } };
        assert.deepEqual(validate(source, { plural: { one: "Une carte", many: "%lld de cartes", other: "%lld cartes" } }, "fr"), []);
        const problems = validate(source, { plural: { one: "Une carte", many: "De cartes", other: "%lld cartes" } }, "fr");
        assert.deepEqual(problems.map((p) => p.message), ["many: placeholders none do not match the source's %lld"]);
    });

    test("a category for a single number knows that number", () => {
        assert.equal(singleNumber("ar", "zero"), 0);
        assert.equal(singleNumber("ar", "one"), 1);
        assert.equal(singleNumber("ar", "two"), 2);
        assert.equal(singleNumber("ar", "few"), undefined);
        assert.equal(singleNumber("en", "one"), 1);
        assert.equal(singleNumber("fr", "one"), undefined, "French one covers 0 and 1");
        assert.equal(singleNumber("ru", "one"), undefined, "Russian one covers 1, 21, 31 …");
        assert.equal(singleNumber("ja", "other"), undefined);
    });

    test("a form for a single number may spell the number out", () => {
        const source: Text = { plural: { one: "%lld card", other: "%lld cards" } };
        const arabic = { zero: "%lld بطاقة", one: "بطاقة واحدة", two: "بطاقتان", few: "%lld بطاقات", many: "%lld بطاقة", other: "%lld بطاقة" };
        assert.deepEqual(validate(source, { plural: arabic }, "ar"), []);
        const french = validate(source, { plural: { one: "Une carte", many: "%lld de cartes", other: "%lld cartes" } }, "fr");
        assert.deepEqual(french.map((p) => p.message), ["one: placeholders none do not match the source's %lld"], "French one also means 0");
        const few = validate(source, { plural: { ...arabic, few: "بطاقات" } }, "ar");
        assert.deepEqual(few.map((p) => p.message), ["few: placeholders none do not match the source's %lld"]);
    });

    test("spelling the number out keeps the other placeholders in place", () => {
        const source: Text = { plural: { one: "%lld card in %@", other: "%lld cards in %@" } };
        const forms = (two: string) => ({ zero: "%lld في %@", one: "بطاقة في %2$@", two, few: "%lld في %@", many: "%lld في %@", other: "%lld في %@" });
        assert.deepEqual(validate(source, { plural: forms("بطاقتان في %2$@") }, "ar"), []);
        const shifted = validate(source, { plural: forms("بطاقتان في %@") }, "ar");
        assert.equal(shifted.length, 1, "an unnumbered %@ would read the count instead of the place");
        assert.match(shifted[0].message, /^two: placeholders/);
    });
});

describe("placeholders", () => {
    const keys = (text: string) => placeholders(text).map((p) => p.raw);

    test("are found in all their forms", () => {
        assert.deepEqual(keys("%@ at %lld, %d%% off, %1$@ and %2$lld, %#@cards@, %arg, %.1f"), ["%@", "%lld", "%d", "%%", "%1$@", "%2$lld", "%#@cards@", "%arg", "%.1f"]);
        assert.deepEqual(keys("100% off, 50 % less"), []);
    });

    test("compare as multisets, so positional reordering is fine", () => {
        assert.deepEqual(validate("%@ from %@", "%2$@ の %1$@", "ja"), []);
        assert.deepEqual(validate("%@ from %@", "%@ の %@", "ja"), []);
        assert.deepEqual(validate("Save 100%%", "100%% sparen", "de"), []);
    });

    test("mismatches are errors", () => {
        assert.equal(validate("At %@", "Bei", "de")[0].kind, "invalid");
        assert.equal(validate("%lld cards", "%d Karten", "de")[0].kind, "invalid");
        assert.equal(validate("At %@", "Bei %@ %@", "de")[0].kind, "invalid");
        assert.equal(validate("Save 100%%", "100% sparen", "de")[0].kind, "invalid");
        assert.equal(validate("%#@cards@ in %@", "%#@karten@ in %@", "de")[0].kind, "invalid");
    });

    test("empty, missing and misshapen translations are caught", () => {
        assert.equal(validate("Add", "  ", "de")[0].kind, "missing");
        assert.equal(validate("Add", undefined, "de")[0].kind, "missing");
        assert.equal(validate("Add", { plural: { other: "x" } }, "de")[0].kind, "invalid");
        assert.equal(validate({ plural: { other: "%lld" } }, "%lld", "de")[0].kind, "invalid");
    });

    test("device variants and substitutions are checked inside", () => {
        const device: Text = { device: { iphone: "Tap %@", other: "Click %@" } };
        assert.deepEqual(validate(device, { device: { iphone: "Tippe %@", other: "Klicke %@" } }, "de"), []);
        assert.match(validate(device, { device: { iphone: "Tippe %@" } }, "de")[0].message, /^other: no translation/);
        const format: Text = { format: "%#@cards@ in %@", substitutions: { cards: { plural: { one: "%arg card", other: "%arg cards" } } } };
        assert.deepEqual(validate(format, { format: "%#@cards@ in %@", substitutions: { cards: { plural: { other: "%arg 枚" } } } }, "ja"), []);
        assert.match(validate(format, { format: "%#@cards@ in %@", substitutions: { cards: { plural: { other: "枚" } } } }, "ja")[0].message, /^cards\.other: placeholders/);
    });
});

describe("completeness", () => {
    const catalogue = catalogueOf({
        "Done": { localizations: { de: unit("Fertig"), fr: unit("Terminé", "needs_review") } },
        "Old": { extractionState: "stale", localizations: { de: unit("Alt") } },
        "Brand": { shouldTranslate: false },
        "At %@": { localizations: { de: unit("Bei"), fr: unit("À %@", "new") } },
    });

    test("assess sorts every unit into one status", () => {
        const { units, stale, untranslatable } = unitsOf(catalogue);
        assert.deepEqual(units.map((u) => u.key), ["At %@", "Done"]);
        assert.deepEqual(stale, ["Old"]);
        assert.equal(untranslatable, 1);
        const status = (key: string, lang: string) => assess(units.find((u) => u.key === key)!, lang).status;
        assert.equal(status("Done", "de"), "translated");
        assert.equal(status("Done", "fr"), "review");
        assert.equal(status("Done", "ja"), "missing");
        assert.equal(status("At %@", "de"), "invalid");
        assert.equal(status("At %@", "fr"), "missing");
    });

    test("check reports errors per unit and warns about stale keys", () => {
        const { errors, warnings } = checkReport([catalogue], ["de", "fr"]);
        assert.deepEqual(warnings, ['Cards/Localizable.xcstrings: 1 stale key no longer in the code: "Old"']);
        assert.deepEqual(errors, [
            'Cards/Localizable.xcstrings [de] "At %@": placeholders none do not match the source\'s %@',
            'Cards/Localizable.xcstrings [fr] "At %@": not translated yet (state new)',
            'Cards/Localizable.xcstrings [fr] "Done": needs review (state needs_review)',
        ]);
    });

    test("check fails on translations for a language the project does not have", () => {
        const catalogue = catalogueOf({ Edit: { localizations: { ja: unit("編集"), fr: unit("Modifier") } } });
        const { errors } = checkReport([catalogue], ["ja"]);
        assert.deepEqual(errors, ["Cards/Localizable.xcstrings [fr]: 1 translation for a language the project does not have; take them out with node scripts/remove-language.ts fr, or add it back with node scripts/add-language.ts fr"]);
    });
});

describe("the app's, the widget's and the watch's catalogues", () => {
    test("are found under Cards/, CardsWidget/ and CardsWatch/, leaving out Cards/Development and everything else", () => {
        const root = projectWithWidget();
        try {
            const empty = formatCatalogue({ sourceLanguage: "en", strings: {}, version: "1.0" });
            writeFileSync(join(root, "CardsWidget", "InfoPlist.xcstrings"), empty);
            mkdirSync(join(root, "CardsWatch"), { recursive: true });
            writeFileSync(join(root, "CardsWatch", "Localizable.xcstrings"), empty);
            mkdirSync(join(root, "scripts", "fixtures"), { recursive: true });
            writeFileSync(join(root, "scripts", "fixtures", "Fixture.xcstrings"), empty);
            const found = findCatalogues(projectAt(root)).map((path) => relative(root, path));
            assert.deepEqual(found, [
                "Cards/Localizable.xcstrings",
                "CardsWatch/Localizable.xcstrings",
                "CardsWidget/InfoPlist.xcstrings",
                "CardsWidget/Localizable.xcstrings",
            ]);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });
});

describe("the project's knownRegions", () => {
    const before = readFileSync(join(fixtures, "pbxproj", "before.pbxproj"), "utf8");
    const after = readFileSync(join(fixtures, "pbxproj", "after.pbxproj"), "utf8");

    test("are read, quoted or not, without en and Base", () => {
        assert.deepEqual(readKnownRegions(before), ["en", "Base"]);
        assert.deepEqual(projectLanguages(after), ["ar", "de", "es", "fr", "it", "ja", "ko", "pt-BR", "zh-Hans", "zh-Hant"]);
    });

    test("adding the app's ten languages reproduces the real project edit exactly", () => {
        let text = before;
        for (const code of ["ar", "de", "es", "fr", "it", "ja", "ko", "pt-BR", "zh-Hans", "zh-Hant"]) text = addKnownRegion(text, code).text;
        assert.equal(text, after);
    });

    test("adding a language twice changes nothing", () => {
        assert.deepEqual(addKnownRegion(after, "ja"), { text: after, changed: false });
        assert.deepEqual(addKnownRegion(after, "zh-Hans"), { text: after, changed: false });
    });

    test("taking the ten languages out again gives back the project as it was", () => {
        let text = after;
        for (const code of ["zh-Hant", "ar", "ja", "pt-BR", "de", "es", "fr", "it", "ko", "zh-Hans"]) text = removeKnownRegion(text, code).text;
        assert.equal(text, before);
        assert.deepEqual(removeKnownRegion(before, "ja"), { text: before, changed: false });
    });

    test("every list is edited, hyphenated codes are quoted, and nothing else moves", () => {
        const two = "\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t);\n\t\t\tother = 1;\n\t\tknownRegions = (\n\t\t\ten,\n\t\t\tBase,\n\t\t);\n";
        const { text, changed } = addKnownRegion(two, "pt-BR");
        assert.ok(changed);
        assert.equal(text, "\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\t\"pt-BR\",\n\t\t\t);\n\t\t\tother = 1;\n\t\tknownRegions = (\n\t\t\ten,\n\t\t\tBase,\n\t\t\t\"pt-BR\",\n\t\t);\n");
        assert.equal(addKnownRegion(two, "ja").text.split("\n").filter((line) => line.trim() === "ja,").length, 2);
    });
});

describe("language codes", () => {
    test("are canonicalised and named", () => {
        assert.equal(canonicalLanguage("pt_br"), "pt-BR");
        assert.equal(canonicalLanguage("zh-hans"), "zh-Hans");
        assert.equal(canonicalLanguage(" EN-gb "), "en-GB");
        assert.equal(languageName("pt-BR"), "Brazilian Portuguese");
        assert.equal(languageName("zh-Hant"), "Traditional Chinese");
    });

    test("nonsense is refused", () => {
        assert.throws(() => canonicalLanguage("xx-!!"), /not a valid language code/);
        assert.throws(() => canonicalLanguage("Base"), /not a valid language code/);
        assert.equal(languageName("qq"), undefined);
    });
});

describe("taking a language out and bringing it back", () => {
    test("restoring skips a string whose English changed, and keeps translations already there", () => {
        const before = catalogueOf({ Edit: { localizations: { ja: unit("編集") } }, Old: { localizations: { ja: unit("古い") } } });
        const now = catalogueOf({ Edit: {}, Old: { localizations: { en: unit("New") } }, Kept: { localizations: { ja: unit("そのまま") } } });
        assert.equal(restoreLanguage([now], new Map([[now.name, before.doc]]), "ja"), 1);
        assert.deepEqual(now.doc.strings.Edit.localizations?.ja, unit("編集"));
        assert.equal(now.doc.strings.Old.localizations?.ja, undefined);
        assert.equal(removeLanguage([now], "ja"), 2);
    });
});
