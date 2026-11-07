// Tests for scripts/translate-strings.ts, run on copies of the fixture project
// with a fake AI. Run with: node --test scripts/translate-strings.test.ts
//
// Set L10N_SMOKE=1 to also run the real default AI command end to end.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { cpSync, existsSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { describe, test } from "node:test";

import { assertUsage, projectCopy, projectWithWidget, readJSON, runScript, unit } from "./fixtures/string-catalogues/test-project.ts";
import { formatCatalogue, parseCatalogue } from "./lib/string-catalogues.ts";

const translateStrings = (root: string, args: string[] = [], env: Record<string, string> = {}) => runScript("translate-strings", root, args, env);
const checkStrings = (root: string) => runScript("check-strings", root, []);

describe("translate-strings", () => {
    test("translates the fixture project and leaves it passing check", () => {
        const root = projectCopy();
        try {
            const result = translateStrings(root);
            assert.equal(result.status, 0, result.stderr);
            const catalogue = join(root, "Cards", "Localizable.xcstrings");
            const doc = readJSON(catalogue);
            assert.deepEqual(doc.strings["%lld cards"].localizations.ja, { variations: { plural: { other: unit("[ja] %lld cards") } } });
            assert.deepEqual(doc.strings.Settings.localizations.ja, unit("[ja] Settings"));
            assert.equal(formatCatalogue(parseCatalogue(readFileSync(catalogue, "utf8"), "x")), readFileSync(catalogue, "utf8"));
            assert.equal(readJSON(join(root, "Cards", "Development", "Storybook.xcstrings")).strings.Storybook.localizations, undefined);
            assert.equal(checkStrings(root).status, 0);
            const again = translateStrings(root);
            assert.match(again.stderr, /ja: nothing to translate/);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("feeds validation problems back and retries", () => {
        const root = projectCopy();
        const promptLog = join(root, "prompts.log");
        try {
            const result = translateStrings(root, ["--lang", "ja"], { FAKE_AI_MODE: "drop-placeholders-once", FAKE_AI_LOG: promptLog });
            assert.equal(result.status, 0, result.stderr);
            const prompts = readFileSync(promptLog, "utf8").split("\n=====\n").filter(Boolean);
            assert.equal(prompts.length, 2);
            assert.match(prompts[1], /## Problems with your previous reply\n\n- "%lld cards" in Cards\/Localizable.xcstrings: other: placeholders none/);
            assert.ok(!prompts[1].includes('"key": "Settings"'), "the retry asks only for the units that failed");
            assert.equal(checkStrings(root).status, 0);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("retries a reply that is not JSON, and accepts a fenced one", () => {
        const root = projectCopy();
        try {
            assert.equal(translateStrings(root, [], { FAKE_AI_MODE: "prose-once" }).status, 0);
            assert.equal(translateStrings(root, ["--force"], { FAKE_AI_MODE: "fence" }).status, 0);
            assert.equal(checkStrings(root).status, 0);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("gives up after three attempts and writes only what passed", () => {
        const root = projectCopy();
        try {
            const result = translateStrings(root, [], { FAKE_AI_MODE: "drop-placeholders" });
            assert.equal(result.status, 1);
            assert.match(result.stderr, /error: Cards\/Localizable.xcstrings \[ja\] "You're at %@. Your barcode is ready.": placeholders none/);
            const doc = readJSON(join(root, "Cards", "Localizable.xcstrings"));
            assert.deepEqual(doc.strings.Settings.localizations.ja, unit("[ja] Settings"));
            assert.equal(doc.strings["You're at %@. Your barcode is ready."].localizations, undefined);
            assert.equal(translateStrings(root, [], { FAKE_AI_MODE: "fail" }).status, 1);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("refuses a language the project does not have", () => {
        const root = projectCopy();
        try {
            const result = translateStrings(root, ["--lang", "fr"]);
            assert.equal(result.status, 2);
            assert.match(result.stderr, /fr is not a project language \(ja\); add it with node scripts\/add-language.ts/);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("prints its usage on --help, and exits 2 on a usage error", () => {
        assertUsage("translate-strings");
    });
});

describe("translate-strings with the app's and the widget's catalogues", () => {
    test("asks once for a string in both, and gives both the same translation", () => {
        const root = projectWithWidget();
        const promptLog = join(root, "prompts.log");
        try {
            const result = translateStrings(root, [], { FAKE_AI_LOG: promptLog });
            assert.equal(result.status, 0, result.stderr);
            const prompts = readFileSync(promptLog, "utf8");
            assert.equal(prompts.split('"key": "Settings"').length - 1, 1, "Settings is asked for once");
            const widget = readJSON(join(root, "CardsWidget", "Localizable.xcstrings"));
            assert.deepEqual(widget.strings.Settings.localizations.ja, unit("[ja] Settings"));
            assert.deepEqual(widget.strings["Find Nearest Card"].localizations.ja, unit("[ja] Find Nearest Card"));
            assert.equal(checkStrings(root).status, 0);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("copies a translation one already has rather than asking again", () => {
        const root = projectCopy();
        const promptLog = join(root, "prompts.log");
        try {
            assert.equal(translateStrings(root).status, 0);
            const widgetRoot = projectWithWidget();
            cpSync(join(widgetRoot, "CardsWidget"), join(root, "CardsWidget"), { recursive: true });
            rmSync(widgetRoot, { recursive: true, force: true });

            const result = translateStrings(root, [], { FAKE_AI_LOG: promptLog });
            assert.equal(result.status, 0, result.stderr);
            assert.match(result.stderr, /ja: 1 copied from the same string in another catalogue/);
            assert.ok(!readFileSync(promptLog, "utf8").includes('"key": "Settings"'), "Settings is not asked for again");
            const widget = readJSON(join(root, "CardsWidget", "Localizable.xcstrings"));
            assert.deepEqual(widget.strings.Settings.localizations.ja, unit("[ja] Settings"));
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });
});

describe("smoke test with the real AI", { skip: process.env.L10N_SMOKE !== "1" && "set L10N_SMOKE=1 to run" }, () => {
    test("the default command translates three strings into Japanese", { timeout: 15 * 60 * 1000 }, () => {
        const root = projectCopy();
        const script = (name: string) => join(import.meta.dirname, `${name}.ts`);
        try {
            const env: Record<string, string> = { ...process.env } as Record<string, string>;
            delete env.L10N_AI_COMMAND;
            const result = spawnSync(process.execPath, [script("translate-strings"), "--root", root, "--lang", "ja"], { encoding: "utf8", env });
            console.log(result.stderr);
            assert.equal(result.status, 0, result.stderr);
            const doc = readJSON(join(root, "Cards", "Localizable.xcstrings"));
            for (const [key, entry] of Object.entries(doc.strings as Record<string, { localizations: Record<string, unknown> }>)) {
                console.log(`${key} => ${JSON.stringify(entry.localizations.ja)}`);
            }
            assert.deepEqual(Object.keys(doc.strings["%lld cards"].localizations.ja.variations.plural), ["other"]);
            assert.match(doc.strings["You're at %@. Your barcode is ready."].localizations.ja.stringUnit.value, /%@/);
            const check = spawnSync(process.execPath, [script("check-strings"), "--root", root], { encoding: "utf8" });
            assert.equal(check.status, 0, check.stderr);
            if (existsSync(join(root, "Cards", "Development", "Storybook.xcstrings"))) {
                assert.equal(readJSON(join(root, "Cards", "Development", "Storybook.xcstrings")).strings.Storybook.localizations, undefined);
            }
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });
});
