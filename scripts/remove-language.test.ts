// Tests for scripts/remove-language.ts, and for bringing the language back with
// scripts/add-language.ts --from, run on a copy of the fixture project in a git
// repository of its own. Run with: node --test scripts/remove-language.test.ts

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { describe, test } from "node:test";

import { assertUsage, projectCopy, readJSON, runScript, unit } from "./fixtures/string-catalogues/test-project.ts";
import { formatCatalogue } from "./lib/string-catalogues.ts";

const git = (root: string, args: string[]): string => {
    const result = spawnSync("git", ["-c", "user.name=Test", "-c", "user.email=test@example.com", ...args], { cwd: root, encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout.trim();
};

describe("remove-language", () => {
    test("a removed language leaves no translations, and comes back from the commit that had them", () => {
        const root = projectCopy();
        const pbxproj = join(root, "Cards.xcodeproj", "project.pbxproj");
        const catalogue = join(root, "Cards", "Localizable.xcstrings");
        try {
            assert.equal(runScript("translate-strings", root, []).status, 0);
            // A translation a person wrote, which the fake AI would never give.
            const doc = readJSON(catalogue);
            doc.strings.Settings.localizations.ja = unit("設定");
            writeFileSync(catalogue, formatCatalogue(doc));
            git(root, ["init", "--quiet"]);
            git(root, ["add", "."]);
            git(root, ["commit", "--quiet", "-m", "with Japanese"]);
            const withJapanese = git(root, ["rev-parse", "--short", "HEAD"]);

            const removed = runScript("remove-language", root, ["ja"]);
            assert.equal(removed.status, 0, removed.stderr);
            assert.match(removed.stdout, /Took ja out of knownRegions and removed its 3 translations/);
            assert.match(removed.stdout, new RegExp(`Bring it back with: node scripts/add-language.ts ja --from ${withJapanese}`));
            assert.doesNotMatch(readFileSync(pbxproj, "utf8"), /\bja,/);
            assert.equal(readJSON(catalogue).strings.Settings.localizations?.ja, undefined);
            assert.equal(runScript("check-strings", root, []).status, 0);
            assert.match(runScript("remove-language", root, ["ja"]).stdout, /not a project language/);
            git(root, ["commit", "--quiet", "-am", "without Japanese"]);

            const restored = runScript("add-language", root, ["ja", "--from", withJapanese]);
            assert.equal(restored.status, 0, restored.stderr);
            assert.match(restored.stdout, /Restored 3 translations into ja/);
            assert.deepEqual(readJSON(catalogue).strings.Settings.localizations.ja, unit("設定"));
            assert.match(restored.stderr, /ja: nothing to translate/);
            assert.equal(runScript("add-language", root, ["ja", "--from", "no-such-commit"]).status, 2);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("prints its usage on --help, and exits 2 on a usage error", () => {
        assertUsage("remove-language");
    });
});
