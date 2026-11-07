// Tests for scripts/export-strings.ts and scripts/import-strings.ts, run on
// copies of the fixture project. Run with: node --test scripts/export-and-import-strings.test.ts

import assert from "node:assert/strict";
import { rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { describe, test } from "node:test";

import { assertUsage, projectCopy, projectWithWidget, readJSON, runScript, unit } from "./fixtures/string-catalogues/test-project.ts";
import { formatCatalogue } from "./lib/string-catalogues.ts";

const exportStrings = (root: string, args: string[]) => runScript("export-strings", root, args);
const importStrings = (root: string, args: string[]) => runScript("import-strings", root, args);
const checkStrings = (root: string) => runScript("check-strings", root, []);

describe("export-strings and import-strings", () => {
    test("round-trip through a file, validated like translate-strings", () => {
        const root = projectCopy();
        const exported = join(root, "ja.json");
        try {
            assert.equal(exportStrings(root, ["--lang", "ja", "--out", exported]).status, 0);
            const payload = readJSON(exported);
            assert.deepEqual(payload.units.map((u: { key: string }) => u.key), ["%lld cards", "Settings", "You're at %@. Your barcode is ready."]);
            payload.units[0].translation = { plural: { other: "%lld 枚のカード" } };
            payload.units[1].translation = "設定";
            payload.units[2].translation = "現在地は%@です。";
            writeFileSync(exported, `\`\`\`json\n${JSON.stringify(payload)}\n\`\`\``);
            const imported = importStrings(root, ["--lang", "ja", exported]);
            assert.equal(imported.status, 0, imported.stderr);
            assert.equal(checkStrings(root).status, 0);

            payload.units = [{ ...payload.units[2], translation: "現在地です。" }];
            writeFileSync(exported, JSON.stringify(payload));
            const rejected = importStrings(root, ["--lang", "ja", exported]);
            assert.equal(rejected.status, 1);
            assert.match(rejected.stderr, /placeholders none do not match the source's %@/);
            assert.equal(readJSON(join(root, "Cards", "Localizable.xcstrings")).strings["You're at %@. Your barcode is ready."].localizations.ja.stringUnit.value, "現在地は%@です。");

            assert.equal(exportStrings(root, ["--lang", "ja", "--out", exported]).status, 0);
            assert.equal(readJSON(exported).units.length, 0);
            assert.equal(exportStrings(root, ["--lang", "ja", "--force", "--out", exported]).status, 0);
            assert.equal(readJSON(exported).units[1].translation, "設定");
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("check-strings fails on a string translated differently in the app's and the widget's catalogues, and one import fixes both", () => {
        const root = projectWithWidget();
        const widgetPath = join(root, "CardsWidget", "Localizable.xcstrings");
        const exported = join(root, "ja.json");
        try {
            assert.equal(runScript("translate-strings", root, []).status, 0);
            const widget = readJSON(widgetPath);
            widget.strings.Settings.localizations.ja = unit("環境設定");
            writeFileSync(widgetPath, formatCatalogue(widget));
            const check = checkStrings(root);
            assert.equal(check.status, 1);
            assert.match(check.stderr, /Cards\/Localizable.xcstrings and CardsWidget\/Localizable.xcstrings \[ja\] "Settings": translated differently/);

            assert.equal(exportStrings(root, ["--lang", "ja", "--force", "--out", exported]).status, 0);
            const payload = readJSON(exported);
            const settings = payload.units.filter((u: { key: string }) => u.key === "Settings");
            assert.deepEqual(settings.map((u: { catalogue: string }) => u.catalogue), ["Cards/Localizable.xcstrings"], "exported once");
            payload.units = [{ ...settings[0], translation: "設定" }];
            writeFileSync(exported, JSON.stringify(payload));
            const imported = importStrings(root, ["--lang", "ja", exported]);
            assert.equal(imported.status, 0, imported.stderr);
            assert.match(imported.stdout, /Imported 1 translation for ja, and 1 to the same string in another catalogue/);
            assert.deepEqual(readJSON(widgetPath).strings.Settings.localizations.ja, unit("設定"));
            assert.equal(checkStrings(root).status, 0);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("print their usage on --help, and exit 2 on a usage error", () => {
        assertUsage("export-strings");
        assertUsage("import-strings");
    });
});
