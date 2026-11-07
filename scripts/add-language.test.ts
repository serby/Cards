// Tests for scripts/add-language.ts, run on a copy of the fixture project with
// a fake AI. Run with: node --test scripts/add-language.test.ts
// Bringing a language back with --from is tested with remove-language.

import assert from "node:assert/strict";
import { readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { describe, test } from "node:test";

import { assertUsage, projectCopy, readJSON, runScript } from "./fixtures/string-catalogues/test-project.ts";

const addLanguage = (root: string, args: string[]) => runScript("add-language", root, args);

describe("add-language", () => {
    test("adds a canonical code to knownRegions and translates it", () => {
        const root = projectCopy();
        const pbxproj = join(root, "Cards.xcodeproj", "project.pbxproj");
        try {
            const result = addLanguage(root, ["pt_br"]);
            assert.equal(result.status, 0, result.stderr);
            assert.match(result.stdout, /Added pt-BR \(Brazilian Portuguese\) to knownRegions/);
            assert.match(readFileSync(pbxproj, "utf8"), /\t\t\t\tja,\n\t\t\t\t"pt-BR",\n\t\t\t\);/);
            const plural = readJSON(join(root, "Cards", "Localizable.xcstrings")).strings["%lld cards"].localizations["pt-BR"].variations.plural;
            assert.deepEqual(Object.keys(plural), ["many", "one", "other"]);
            assert.match(addLanguage(root, ["pt-BR"]).stdout, /already a project language/);
            assert.equal(addLanguage(root, ["qq"]).status, 2);
            assert.equal(addLanguage(root, ["en"]).status, 2);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("prints its usage on --help, and exits 2 on a usage error", () => {
        assertUsage("add-language");
    });
});
