// Tests for scripts/lib/changelog.ts, which generate-changelog.ts,
// check-changelog.ts and print-release-notes.ts share. Run with:
// node --test scripts/changelog.test.ts

import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, test } from "node:test";

import { type Change, type Changelog, type Locales, markdown, readLocales, releaseNotes, staleOutputs, textFor, validate, type Version } from "./lib/changelog.ts";

const locales: Locales = { store: ["de-DE", "en-GB", "en-US", "es-ES", "es-MX", "ja"], app: ["de", "es", "ja", "fr"] };

/// A change with a text for every store locale in `locales`.
const translated = (text: string, extra: Partial<Change> = {}): Change => ({ type: "new", text, de: `${text} (de)`, es: `${text} (es)`, ja: `${text} (ja)`, ...extra });

function changelogOf(newest: Change[], older: Change[] = [{ type: "fixed", text: "An old fix." }]): Changelog {
    return {
        versions: [
            { version: "1.4", date: null, changes: newest },
            { version: "1.3", date: "2026-11-05", changes: older },
        ],
    };
}

describe("a store locale's text", () => {
    const change: Change = { type: "new", text: "Find a shop by postcode.", "en-US": "Find a store by ZIP code.", es: "Busca una tienda por código postal.", "es-MX": "Busca una tienda por código postal (MX)." };

    test("is its own key's, else its language's, else, for English, text", () => {
        assert.equal(textFor(change, "en-GB"), "Find a shop by postcode.");
        assert.equal(textFor(change, "en-US"), "Find a store by ZIP code.");
        assert.equal(textFor(change, "en-AU"), "Find a shop by postcode.");
        assert.equal(textFor(change, "es-MX"), "Busca una tienda por código postal (MX).");
        assert.equal(textFor(change, "es-ES"), "Busca una tienda por código postal.");
        assert.equal(textFor(change, "ja"), undefined);
    });

    test("makes What's New, new first, and fails for a locale a change has no text in", () => {
        const version: Version = { version: "1.4", date: null, changes: [{ type: "fixed", text: "Fixed.", es: "Arreglado." }, change] };
        assert.equal(releaseNotes(version, "es-MX"), "Busca una tienda por código postal (MX).\nArreglado.\n");
        assert.equal(releaseNotes(version, "en-US"), "Find a store by ZIP code.\nFixed.\n");
        assert.throws(() => releaseNotes({ ...version, changes: [change] }, "ja"), /1\.4 has no ja text for "Find a shop by postcode\."/);
    });
});

describe("validation", () => {
    test("accepts app languages and regional texts for store locales of app languages or English", () => {
        const changelog = changelogOf([translated("A.", { "en-US": "A (US).", "es-MX": "A (MX).", fr: "A (fr)." })]);
        assert.deepEqual(validate(changelog, locales), []);
    });

    test("needs a text for every store locale in the newest version only, naming the locales and the change", () => {
        const problems = validate(changelogOf([translated("Share a card."), { type: "new", text: "Search your cards.", es: "Busca tus tarjetas." }]), locales);
        assert.deepEqual(problems, ['versions[0] (1.4): "Search your cards.": no text for de-DE, ja; the newest version\'s What\'s New is generated for every store locale']);
    });

    test("rejects unknown keys, en-GB, and empty texts", () => {
        const problems = validate(changelogOf([translated("A.", { "fr-CA": "A (CA).", en: "A (en).", "en-GB": "A (GB).", es: " " })], [{ type: "fixed", text: "Old.", it: "Vecchio." }]), locales);
        const expected = [
            /^versions\[0\] \(1\.4\): "A\.": unknown field fr-CA; translations are keyed by an app language or a store locale \(de, de-DE, en-US, es, es-ES, es-MX, fr, ja\)$/,
            /^versions\[0\] \(1\.4\): "A\.": unknown field en;/,
            /^versions\[0\] \(1\.4\): "A\.": has an en-GB text, but text is en-GB's$/,
            /^versions\[0\] \(1\.4\): "A\.": its es text is empty$/,
            /^versions\[0\] \(1\.4\): "A\.": no text for es-ES, es-MX;/,
            /^versions\[1\] \(1\.3\): "Old\.": unknown field it;/,
        ];
        assert.equal(problems.length, expected.length, problems.join("\n"));
        for (const pattern of expected) assert.ok(problems.some((problem) => pattern.test(problem)), `no problem matches ${pattern}:\n${problems.join("\n")}`);
    });
});

describe("generated files", () => {
    test("are CHANGELOG.md in British English and every store locale's release_notes.txt", () => {
        const root = mkdtempSync(join(tmpdir(), "changelog-test-"));
        try {
            for (const locale of ["en-GB", "en-US", "es-MX", "ja"]) mkdirSync(join(root, "metadata", locale), { recursive: true });
            mkdirSync(join(root, "Cards.xcodeproj"));
            writeFileSync(join(root, "Cards.xcodeproj", "project.pbxproj"), "knownRegions = (\n\ten,\n\tBase,\n\tes,\n\tja,\n);\n");
            const found = readLocales(root);
            assert.deepEqual(found, { store: ["en-GB", "en-US", "es-MX", "ja"], app: ["es", "ja"] });

            const changelog = changelogOf([{ type: "new", text: "Pick a colour.", "en-US": "Pick a color.", es: "Elige un color.", ja: "色を選べます。" }]);
            assert.deepEqual(validate(changelog, found), []);
            const stale = staleOutputs(changelog, found, root);
            assert.deepEqual(stale.map((output) => output.name), [
                "CHANGELOG.md",
                "metadata/en-GB/release_notes.txt",
                "metadata/en-US/release_notes.txt",
                "metadata/es-MX/release_notes.txt",
                "metadata/ja/release_notes.txt",
            ]);
            for (const output of stale) writeFileSync(output.path, output.text);
            assert.deepEqual(staleOutputs(changelog, found, root), []);
            assert.equal(readFileSync(join(root, "metadata", "es-MX", "release_notes.txt"), "utf8"), "Elige un color.\n");
            assert.equal(readFileSync(join(root, "metadata", "ja", "release_notes.txt"), "utf8"), "色を選べます。\n");
            assert.match(markdown(changelog), /- Pick a colour\.\n/);
            assert.doesNotMatch(markdown(changelog), /Elige/);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });
});
