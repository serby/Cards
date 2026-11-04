// Tests for scripts/l10n.ts. Run with: node --test scripts/l10n.test.ts
//
// fixtures/l10n/format/xcode-saved.xcstrings was written by Xcode 27.1 itself:
// a copy of the app's catalogue seeded with awkward keys and values (emoji,
// NFD, control characters, slashes, numbers, mixed case, language codes whose
// order differs between collations), re-saved by `xcodebuild
// -exportLocalizations`. The pbxproj fixtures are the app's project file just
// before and just after the ten target languages were added.
//
// Set L10N_SMOKE=1 to also run the real default AI command end to end.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";
import { describe, test } from "node:test";

import {
    addKnownRegion,
    assess,
    buildPrompt,
    canonicalLanguage,
    type Catalogue,
    type CatalogueDocument,
    checkReport,
    compareKeys,
    findCatalogues,
    formatCatalogue,
    formatJSON,
    languageName,
    parseCatalogue,
    parseReply,
    payloadFor,
    placeholders,
    pluralCategories,
    projectAt,
    projectLanguages,
    readKnownRegions,
    requiredPluralCategories,
    runCommand,
    singleNumber,
    type Text,
    translate,
    unitsOf,
    validate,
} from "./l10n.ts";

const here = import.meta.dirname;
const fixtures = join(here, "fixtures", "l10n");
const tool = join(here, "l10n.ts");
const fakeAI = join(fixtures, "fake-ai.ts");
const repoBrief = join(here, "..", "l10n", "context.md");

function catalogueOf(strings: CatalogueDocument["strings"], name = "Cards/Localizable.xcstrings"): Catalogue {
    const doc: CatalogueDocument = { sourceLanguage: "en", strings, version: "1.0" };
    return { name, path: join(tmpdir(), "unused.xcstrings"), doc, original: "" };
}

const unit = (value: string, state = "translated") => ({ stringUnit: { state, value } });

/// Every object's keys reversed, so a formatter that does not sort would fail.
function scramble(value: unknown): unknown {
    if (Array.isArray(value)) return value.map(scramble);
    if (value && typeof value === "object") {
        return Object.fromEntries(Object.entries(value).reverse().map(([k, v]) => [k, scramble(v)]));
    }
    return value;
}

/// A copy of the fixture project in a temporary directory, with the real brief.
function projectCopy(): string {
    const root = mkdtempSync(join(tmpdir(), "l10n-test-"));
    cpSync(join(fixtures, "project"), root, { recursive: true });
    cpSync(repoBrief, join(root, "l10n", "context.md"));
    return root;
}

function cli(root: string, args: string[], env: Record<string, string> = {}) {
    const result = spawnSync(process.execPath, [tool, "--root", root, ...args], {
        encoding: "utf8",
        env: { ...process.env, L10N_AI_BACKOFF_MS: "0", L10N_AI_COMMAND: `"${process.execPath}" "${fakeAI}"`, ...env },
    });
    return { status: result.status, stdout: result.stdout, stderr: result.stderr };
}

const readJSON = (path: string) => JSON.parse(readFileSync(path, "utf8"));

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
        assert.equal(formatJSON({ s: "a/b é 🎉   \u007f" }), '{\n  "s" : "a/b é 🎉   \u007f"\n}');
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
});

describe("the app's and the widget's catalogues", () => {
    /// The fixture project with a widget catalogue beside the app's: "Settings"
    /// is a twin of the app's, as a file compiled into both targets makes it,
    /// and "Find Nearest Card" is the widget's own.
    function projectWithWidget(): string {
        const root = projectCopy();
        mkdirSync(join(root, "CardsWidget"), { recursive: true });
        writeFileSync(
            join(root, "CardsWidget", "Localizable.xcstrings"),
            formatCatalogue({
                sourceLanguage: "en",
                strings: {
                    "Find Nearest Card": { comment: "Title of the widget's refresh action." },
                    "Settings": { comment: "Tab bar item and navigation title of the Settings screen." },
                },
                version: "1.0",
            }),
        );
        return root;
    }

    test("are found under Cards/ and CardsWidget/, leaving out Cards/Development and everything else", () => {
        const root = projectWithWidget();
        try {
            const empty = formatCatalogue({ sourceLanguage: "en", strings: {}, version: "1.0" });
            writeFileSync(join(root, "CardsWidget", "InfoPlist.xcstrings"), empty);
            mkdirSync(join(root, "scripts", "fixtures"), { recursive: true });
            writeFileSync(join(root, "scripts", "fixtures", "Fixture.xcstrings"), empty);
            const found = findCatalogues(projectAt(root)).map((path) => relative(root, path));
            assert.deepEqual(found, ["Cards/Localizable.xcstrings", "CardsWidget/InfoPlist.xcstrings", "CardsWidget/Localizable.xcstrings"]);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("ask once for a string in both, and give both the same translation", () => {
        const root = projectWithWidget();
        const promptLog = join(root, "prompts.log");
        try {
            const result = cli(root, ["translate"], { FAKE_AI_LOG: promptLog });
            assert.equal(result.status, 0, result.stderr);
            const prompts = readFileSync(promptLog, "utf8");
            assert.equal(prompts.split('"key": "Settings"').length - 1, 1, "Settings is asked for once");
            const widget = readJSON(join(root, "CardsWidget", "Localizable.xcstrings"));
            assert.deepEqual(widget.strings.Settings.localizations.ja, unit("[ja] Settings"));
            assert.deepEqual(widget.strings["Find Nearest Card"].localizations.ja, unit("[ja] Find Nearest Card"));
            assert.equal(cli(root, ["check"]).status, 0);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("copy a translation one already has rather than asking again", () => {
        const root = projectCopy();
        const promptLog = join(root, "prompts.log");
        try {
            assert.equal(cli(root, ["translate"]).status, 0);
            const widgetRoot = projectWithWidget();
            cpSync(join(widgetRoot, "CardsWidget"), join(root, "CardsWidget"), { recursive: true });
            rmSync(widgetRoot, { recursive: true, force: true });

            const result = cli(root, ["translate"], { FAKE_AI_LOG: promptLog });
            assert.equal(result.status, 0, result.stderr);
            assert.match(result.stderr, /ja: 1 copied from the same string in another catalogue/);
            assert.ok(!readFileSync(promptLog, "utf8").includes('"key": "Settings"'), "Settings is not asked for again");
            const widget = readJSON(join(root, "CardsWidget", "Localizable.xcstrings"));
            assert.deepEqual(widget.strings.Settings.localizations.ja, unit("[ja] Settings"));
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("must agree: check fails on twins translated differently, and import fixes both", () => {
        const root = projectWithWidget();
        const widgetPath = join(root, "CardsWidget", "Localizable.xcstrings");
        const exported = join(root, "ja.json");
        try {
            assert.equal(cli(root, ["translate"]).status, 0);
            const widget = readJSON(widgetPath);
            widget.strings.Settings.localizations.ja = unit("環境設定");
            writeFileSync(widgetPath, formatCatalogue(widget));
            const check = cli(root, ["check"]);
            assert.equal(check.status, 1);
            assert.match(check.stderr, /Cards\/Localizable.xcstrings and CardsWidget\/Localizable.xcstrings \[ja\] "Settings": translated differently/);

            assert.equal(cli(root, ["export", "--lang", "ja", "--force", "--out", exported]).status, 0);
            const payload = readJSON(exported);
            const settings = payload.units.filter((u: { key: string }) => u.key === "Settings");
            assert.deepEqual(settings.map((u: { catalogue: string }) => u.catalogue), ["Cards/Localizable.xcstrings"], "exported once");
            payload.units = [{ ...settings[0], translation: "設定" }];
            writeFileSync(exported, JSON.stringify(payload));
            const imported = cli(root, ["import", "--lang", "ja", exported]);
            assert.equal(imported.status, 0, imported.stderr);
            assert.match(imported.stdout, /Imported 1 translation for ja, and 1 to the same string in another catalogue/);
            assert.deepEqual(readJSON(widgetPath).strings.Settings.localizations.ja, unit("設定"));
            assert.equal(cli(root, ["check"]).status, 0);
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

describe("replies", () => {
    const body = '{"targetLanguage": "ja", "units": [{"catalogue": "Cards/Localizable.xcstrings", "key": "Settings", "translation": "設定"}]}';
    const expected = [{ catalogue: "Cards/Localizable.xcstrings", key: "Settings", translation: "設定" }];

    test("parse as strict JSON", () => {
        assert.deepEqual(parseReply(body, "ja"), expected);
        assert.deepEqual(parseReply(`\n  ${body}\n`, "ja"), expected);
        assert.deepEqual(parseReply(JSON.stringify(expected)), expected);
    });

    test("tolerate one code fence around the whole reply", () => {
        assert.deepEqual(parseReply(`\`\`\`json\n${body}\n\`\`\``, "ja"), expected);
        assert.deepEqual(parseReply(`\`\`\`\n${body}\n\`\`\`\n`, "ja"), expected);
    });

    test("refuse anything else", () => {
        assert.throws(() => parseReply(`Here you go:\n${body}`, "ja"), /not valid JSON/);
        assert.throws(() => parseReply(`\`\`\`json\n${body}\n\`\`\`\nHope that helps!`, "ja"), /not valid JSON/);
        assert.throws(() => parseReply('{"translations": []}', "ja"), /no "units" list/);
        assert.throws(() => parseReply(body, "ko"), /for ja, not ko/);
        assert.throws(() => parseReply('{"units": [{"key": "Settings"}]}', "ja"), /unit 1 .*"catalogue"/);
    });
});

describe("the prompt", () => {
    const catalogue = catalogueOf({
        "%lld cards": { comment: "How many cards", localizations: { en: { variations: { plural: { one: unit("%lld card"), other: unit("%lld cards") } } } } },
        "At %@": { comment: "A place name", localizations: { ja: unit("at", "needs_review") } },
    });
    const payload = payloadFor(unitsOf(catalogue).units, "ja");

    test("the payload carries what a translator needs", () => {
        assert.equal(payload.targetLanguageName, "Japanese");
        assert.deepEqual(payload.units, [
            { catalogue: "Cards/Localizable.xcstrings", key: "%lld cards", comment: "How many cards", source: { plural: { one: "%lld card", other: "%lld cards" } }, placeholders: ["%lld"], pluralCategories: ["other"], translation: null },
            { catalogue: "Cards/Localizable.xcstrings", key: "At %@", comment: "A place name", source: "At %@", placeholders: ["%@"], translation: "at" },
        ]);
    });

    test("includes the brief, the language notes, Apple's conventions and any problems", () => {
        const prompt = buildPrompt(payload, "BRIEF TEXT", "NOTES TEXT", { units: [{ catalogue: "Cards/Localizable.xcstrings", key: "At %@", translation: "で", problems: ["placeholders none do not match the source's %@"] }] });
        for (const part of ["BRIEF TEXT", "## Notes for Japanese", "NOTES TEXT", "Apple", "Lock Screen", "Wallet", "formality", "pluralCategories", "## Problems with your previous reply", 'you wrote "で"']) {
            assert.ok(prompt.includes(part), `prompt should include ${part}`);
        }
        const input = /```json\n([\s\S]*)\n```\n$/.exec(prompt);
        assert.ok(input);
        assert.deepEqual(JSON.parse(input[1]), payload);
    });
});

describe("translate", () => {
    test("merges in a fixed order, however the languages finish", async () => {
        const make = () => [catalogueOf({ "Add": {}, "%lld cards": { localizations: { en: { variations: { plural: { one: unit("%lld card"), other: unit("%lld cards") } } } } } })];
        const answer = (prompt: string, lang: string) => {
            const payload = JSON.parse(/```json\n([\s\S]*)\n```\n$/.exec(prompt)![1]);
            const units = payload.units.map((u: { catalogue: string; key: string; pluralCategories?: string[] }) => ({
                catalogue: u.catalogue,
                key: u.key,
                translation: u.pluralCategories ? { plural: Object.fromEntries(u.pluralCategories.map((c) => [c, `%lld ${lang}`])) } : `${u.key} ${lang}`,
            }));
            return JSON.stringify({ targetLanguage: lang, units });
        };
        const run = async (delays: Record<string, number>) => {
            const catalogues = make();
            await translate(catalogues, {
                languages: ["de", "fr", "ja"],
                force: false,
                jobs: 3,
                batchSize: 50,
                brief: "",
                notes: () => undefined,
                ask: (prompt, lang) => new Promise((resolve) => setTimeout(() => resolve(answer(prompt, lang)), delays[lang])),
                log: () => {},
            });
            return formatCatalogue(catalogues[0].doc);
        };
        const first = await run({ de: 30, fr: 1, ja: 15 });
        assert.equal(await run({ de: 1, fr: 30, ja: 15 }), first);
        assert.equal(Object.keys(JSON.parse(first).strings.Add.localizations).join(), "de,fr,ja");
    });

    test("translates the fixture project and leaves it passing check", () => {
        const root = projectCopy();
        try {
            const result = cli(root, ["translate"]);
            assert.equal(result.status, 0, result.stderr);
            const catalogue = join(root, "Cards", "Localizable.xcstrings");
            const doc = readJSON(catalogue);
            assert.deepEqual(doc.strings["%lld cards"].localizations.ja, { variations: { plural: { other: unit("[ja] %lld cards") } } });
            assert.deepEqual(doc.strings.Settings.localizations.ja, unit("[ja] Settings"));
            assert.equal(formatCatalogue(parseCatalogue(readFileSync(catalogue, "utf8"), "x")), readFileSync(catalogue, "utf8"));
            assert.equal(readJSON(join(root, "Cards", "Development", "Storybook.xcstrings")).strings.Storybook.localizations, undefined);
            assert.equal(cli(root, ["check"]).status, 0);
            const again = cli(root, ["translate"]);
            assert.match(again.stderr, /ja: nothing to translate/);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("feeds validation problems back and retries", () => {
        const root = projectCopy();
        const promptLog = join(root, "prompts.log");
        try {
            const result = cli(root, ["translate", "--lang", "ja"], { FAKE_AI_MODE: "drop-placeholders-once", FAKE_AI_LOG: promptLog });
            assert.equal(result.status, 0, result.stderr);
            const prompts = readFileSync(promptLog, "utf8").split("\n=====\n").filter(Boolean);
            assert.equal(prompts.length, 2);
            assert.match(prompts[1], /## Problems with your previous reply\n\n- "%lld cards" in Cards\/Localizable.xcstrings: other: placeholders none/);
            assert.ok(!prompts[1].includes('"key": "Settings"'), "the retry asks only for the units that failed");
            assert.equal(cli(root, ["check"]).status, 0);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("retries a reply that is not JSON, and accepts a fenced one", () => {
        const root = projectCopy();
        try {
            assert.equal(cli(root, ["translate"], { FAKE_AI_MODE: "prose-once" }).status, 0);
            assert.equal(cli(root, ["translate", "--force"], { FAKE_AI_MODE: "fence" }).status, 0);
            assert.equal(cli(root, ["check"]).status, 0);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("gives up after three attempts and writes only what passed", () => {
        const root = projectCopy();
        try {
            const result = cli(root, ["translate"], { FAKE_AI_MODE: "drop-placeholders" });
            assert.equal(result.status, 1);
            assert.match(result.stderr, /error: Cards\/Localizable.xcstrings \[ja\] "You're at %@. Your barcode is ready.": placeholders none/);
            const doc = readJSON(join(root, "Cards", "Localizable.xcstrings"));
            assert.deepEqual(doc.strings.Settings.localizations.ja, unit("[ja] Settings"));
            assert.equal(doc.strings["You're at %@. Your barcode is ready."].localizations, undefined);
            assert.equal(cli(root, ["translate"], { FAKE_AI_MODE: "fail" }).status, 1);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("refuses a language the project does not have", () => {
        const root = projectCopy();
        try {
            const result = cli(root, ["translate", "--lang", "fr"]);
            assert.equal(result.status, 2);
            assert.match(result.stderr, /fr is not a project language \(ja\); add it with add-language/);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });
});

describe("export and import", () => {
    test("round-trip through a file, validated like translate", () => {
        const root = projectCopy();
        const exported = join(root, "ja.json");
        try {
            assert.equal(cli(root, ["export", "--lang", "ja", "--out", exported]).status, 0);
            const payload = readJSON(exported);
            assert.deepEqual(payload.units.map((u: { key: string }) => u.key), ["%lld cards", "Settings", "You're at %@. Your barcode is ready."]);
            payload.units[0].translation = { plural: { other: "%lld 枚のカード" } };
            payload.units[1].translation = "設定";
            payload.units[2].translation = "現在地は%@です。";
            writeFileSync(exported, `\`\`\`json\n${JSON.stringify(payload)}\n\`\`\``);
            const imported = cli(root, ["import", "--lang", "ja", exported]);
            assert.equal(imported.status, 0, imported.stderr);
            assert.equal(cli(root, ["check"]).status, 0);

            payload.units = [{ ...payload.units[2], translation: "現在地です。" }];
            writeFileSync(exported, JSON.stringify(payload));
            const rejected = cli(root, ["import", "--lang", "ja", exported]);
            assert.equal(rejected.status, 1);
            assert.match(rejected.stderr, /placeholders none do not match the source's %@/);
            assert.equal(readJSON(join(root, "Cards", "Localizable.xcstrings")).strings["You're at %@. Your barcode is ready."].localizations.ja.stringUnit.value, "現在地は%@です。");

            assert.equal(cli(root, ["export", "--lang", "ja", "--out", exported]).status, 0);
            assert.equal(readJSON(exported).units.length, 0);
            assert.equal(cli(root, ["export", "--lang", "ja", "--force", "--out", exported]).status, 0);
            assert.equal(readJSON(exported).units[1].translation, "設定");
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });
});

describe("add-language", () => {
    test("adds a canonical code to knownRegions and translates it", () => {
        const root = projectCopy();
        const pbxproj = join(root, "Cards.xcodeproj", "project.pbxproj");
        try {
            const result = cli(root, ["add-language", "pt_br"]);
            assert.equal(result.status, 0, result.stderr);
            assert.match(result.stdout, /Added pt-BR \(Brazilian Portuguese\) to knownRegions/);
            assert.match(readFileSync(pbxproj, "utf8"), /\t\t\t\tja,\n\t\t\t\t"pt-BR",\n\t\t\t\);/);
            const plural = readJSON(join(root, "Cards", "Localizable.xcstrings")).strings["%lld cards"].localizations["pt-BR"].variations.plural;
            assert.deepEqual(Object.keys(plural), ["many", "one", "other"]);
            assert.match(cli(root, ["add-language", "pt-BR"]).stdout, /already a project language/);
            assert.equal(cli(root, ["add-language", "qq"]).status, 2);
            assert.equal(cli(root, ["add-language", "en"]).status, 2);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });
});

describe("status and normalise", () => {
    test("status counts each catalogue and language", () => {
        const root = projectCopy();
        try {
            const result = cli(root, ["status"]);
            assert.equal(result.status, 0);
            assert.match(result.stdout, /Cards\/Localizable.xcstrings: 3 to translate, 0 not translatable, 0 stale/);
            assert.match(result.stdout, /Cards\/Localizable.xcstrings\s+ja\s+0\s+3\s+0\s+0\s+0/);
            assert.ok(!result.stdout.includes("Storybook"));
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("normalise rewrites a catalogue in Xcode's format, once", () => {
        const root = projectCopy();
        const path = join(root, "Cards", "Localizable.xcstrings");
        try {
            const xcode = readFileSync(path, "utf8");
            writeFileSync(path, `${JSON.stringify(scramble(JSON.parse(xcode)))}\n`);
            assert.match(cli(root, ["normalise"]).stdout, /Rewrote Cards\/Localizable.xcstrings/);
            assert.equal(readFileSync(path, "utf8"), xcode);
            assert.match(cli(root, ["normalise"]).stdout, /already in Xcode's format/);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });
});

describe("the AI command", () => {
    test("is stopped, with everything it started, when it times out", async () => {
        const marker = `${Date.now() % 100000}.${process.pid}`;
        const started = Date.now();
        await assert.rejects(runCommand(`sleep 30 & sleep ${marker}; wait`, "", 300, tmpdir()), /timed out/);
        assert.ok(Date.now() - started < 5000);
        await new Promise((resolve) => setTimeout(resolve, 200));
        assert.notEqual(spawnSync("pgrep", ["-f", `sleep ${marker}`]).status, 0, "no sleep left running");
    });

    test("reports a failure with its stderr", async () => {
        await assert.rejects(runCommand("cat >/dev/null; echo broken >&2; exit 3", "prompt", 5000, tmpdir()), /exited with 3: broken/);
        assert.equal(await runCommand("tr a-z A-Z", "prompt", 5000, tmpdir()), "PROMPT");
    });
});

describe("smoke test with the real AI", { skip: process.env.L10N_SMOKE !== "1" && "set L10N_SMOKE=1 to run" }, () => {
    test("the default command translates three strings into Japanese", { timeout: 15 * 60 * 1000 }, () => {
        const root = projectCopy();
        try {
            const env: Record<string, string> = { ...process.env } as Record<string, string>;
            delete env.L10N_AI_COMMAND;
            const result = spawnSync(process.execPath, [tool, "--root", root, "translate", "--lang", "ja"], { encoding: "utf8", env });
            console.log(result.stderr);
            assert.equal(result.status, 0, result.stderr);
            const doc = readJSON(join(root, "Cards", "Localizable.xcstrings"));
            for (const [key, entry] of Object.entries(doc.strings as Record<string, { localizations: Record<string, unknown> }>)) {
                console.log(`${key} => ${JSON.stringify(entry.localizations.ja)}`);
            }
            assert.deepEqual(Object.keys(doc.strings["%lld cards"].localizations.ja.variations.plural), ["other"]);
            assert.match(doc.strings["You're at %@. Your barcode is ready."].localizations.ja.stringUnit.value, /%@/);
            const check = spawnSync(process.execPath, [tool, "--root", root, "check"], { encoding: "utf8" });
            assert.equal(check.status, 0, check.stderr);
            if (existsSync(join(root, "Cards", "Development", "Storybook.xcstrings"))) {
                assert.equal(readJSON(join(root, "Cards", "Development", "Storybook.xcstrings")).strings.Storybook.localizations, undefined);
            }
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });
});
