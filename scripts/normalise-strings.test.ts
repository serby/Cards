// Tests for scripts/normalise-strings.ts, run on a copy of the fixture project.
// Run with: node --test scripts/normalise-strings.test.ts

import assert from "node:assert/strict";
import { readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { describe, test } from "node:test";

import { assertUsage, projectCopy, runScript, scramble } from "./fixtures/string-catalogues/test-project.ts";

describe("normalise-strings", () => {
    test("rewrites a catalogue in Xcode's format, once", () => {
        const root = projectCopy();
        const path = join(root, "Cards", "Localizable.xcstrings");
        try {
            const xcode = readFileSync(path, "utf8");
            writeFileSync(path, `${JSON.stringify(scramble(JSON.parse(xcode)))}\n`);
            assert.match(runScript("normalise-strings", root, []).stdout, /Rewrote Cards\/Localizable.xcstrings/);
            assert.equal(readFileSync(path, "utf8"), xcode);
            assert.match(runScript("normalise-strings", root, []).stdout, /already in Xcode's format/);
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("prints its usage on --help, and exits 2 on a usage error", () => {
        assertUsage("normalise-strings");
    });
});
